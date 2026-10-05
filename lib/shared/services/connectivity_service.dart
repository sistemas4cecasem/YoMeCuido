import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

enum ConnectivityStatus { checking, online, offline }

abstract class NetworkInterfaceMonitor {
  Future<bool> hasNetworkInterface();

  Stream<bool> get onNetworkInterfaceChanged;

  Future<void> dispose();
}

class ConnectivityPlusNetworkInterfaceMonitor
    implements NetworkInterfaceMonitor {
  ConnectivityPlusNetworkInterfaceMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasNetworkInterface() async {
    final results = await _connectivity.checkConnectivity();
    return _hasUsableInterface(results);
  }

  @override
  Stream<bool> get onNetworkInterfaceChanged {
    return _connectivity.onConnectivityChanged.map(_hasUsableInterface);
  }

  @override
  Future<void> dispose() async {}

  bool _hasUsableInterface(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

abstract class BackendConnectivityProbe {
  Future<bool> canReachBackend({required Duration timeout});
}

class FirestoreBackendConnectivityProbe implements BackendConnectivityProbe {
  FirestoreBackendConnectivityProbe({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const _categoriesCollection = 'categories';

  final FirebaseFirestore? _firestore;

  @override
  Future<bool> canReachBackend({required Duration timeout}) async {
    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await firestore
          .collection(_categoriesCollection)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } on FirebaseException catch (error) {
      // A permission response still proves Firebase was reachable; interface
      // availability alone is never treated as Internet connectivity.
      return error.code == 'permission-denied';
    } catch (_) {
      return false;
    }
  }
}

class ConnectivityService extends ChangeNotifier with WidgetsBindingObserver {
  ConnectivityService({
    NetworkInterfaceMonitor? networkMonitor,
    BackendConnectivityProbe? backendProbe,
    Duration backendTimeout = const Duration(seconds: 4),
    Duration checkCooldown = const Duration(seconds: 3),
  }) : _networkMonitor =
           networkMonitor ?? ConnectivityPlusNetworkInterfaceMonitor(),
       _backendProbe = backendProbe ?? FirestoreBackendConnectivityProbe(),
       _backendTimeout = backendTimeout,
       _checkCooldown = checkCooldown;

  final NetworkInterfaceMonitor _networkMonitor;
  final BackendConnectivityProbe _backendProbe;
  final Duration _backendTimeout;
  final Duration _checkCooldown;

  ConnectivityStatus _status = ConnectivityStatus.checking;
  StreamSubscription<bool>? _networkSubscription;
  Future<bool>? _currentCheck;
  int _checkGeneration = 0;
  bool _isStarted = false;
  bool _shouldCheckAgain = false;
  bool _queuedCheckMustForce = false;
  DateTime? _lastCompletedCheckAt;
  bool _isDisposed = false;
  Timer? _offlineRetryTimer;
  bool _isForeground = true;

  ConnectivityStatus get status => _status;

  bool get isOnline => _status == ConnectivityStatus.online;

  bool get isOffline => _status == ConnectivityStatus.offline;

  Future<void> start() async {
    if (_isStarted || _isDisposed) {
      return;
    }
    _isStarted = true;
    WidgetsBinding.instance.addObserver(this);
    _networkSubscription = _networkMonitor.onNetworkInterfaceChanged.listen((
      _,
    ) {
      _requestFreshCheck(force: true);
    });
    unawaited(checkConnection());
  }

  Future<bool> checkConnection({bool force = false}) {
    if (_isDisposed) {
      return Future<bool>.value(false);
    }

    final activeCheck = _currentCheck;
    if (activeCheck != null) {
      return activeCheck;
    }

    final lastCheckAt = _lastCompletedCheckAt;
    if (!force &&
        lastCheckAt != null &&
        DateTime.now().difference(lastCheckAt) < _checkCooldown) {
      return Future<bool>.value(_status == ConnectivityStatus.online);
    }

    final generation = ++_checkGeneration;
    final check = _checkConnection(generation);
    _currentCheck = check;
    check.whenComplete(() {
      if (identical(_currentCheck, check)) {
        _currentCheck = null;
        _lastCompletedCheckAt = DateTime.now();
        _runQueuedCheckIfNeeded();
        _scheduleOfflineRetry();
      }
    });
    return check;
  }

  void _requestFreshCheck({bool force = false}) {
    if (_isDisposed) {
      return;
    }
    if (_currentCheck != null) {
      _shouldCheckAgain = true;
      _queuedCheckMustForce = _queuedCheckMustForce || force;
      return;
    }
    unawaited(checkConnection(force: force));
  }

  void _scheduleOfflineRetry() {
    _offlineRetryTimer?.cancel();
    if (!_isStarted || _isDisposed || !_isForeground || !isOffline) return;
    // Internet can return without a new Wi-Fi/mobile interface event.
    _offlineRetryTimer = Timer(const Duration(seconds: 5), () {
      _requestFreshCheck(force: true);
    });
  }

  Future<bool> _checkConnection(int generation) async {
    if (!isOffline) _setStatus(ConnectivityStatus.checking);

    final hasInterface = await _safeHasNetworkInterface();
    if (!hasInterface) {
      _applyResult(generation, ConnectivityStatus.offline);
      return false;
    }

    final backendReachable = await _safeCanReachBackend();
    _applyResult(
      generation,
      backendReachable ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );
    return backendReachable;
  }

  void _runQueuedCheckIfNeeded() {
    if (!_shouldCheckAgain) {
      return;
    }
    _shouldCheckAgain = false;
    final force = _queuedCheckMustForce;
    _queuedCheckMustForce = false;
    unawaited(checkConnection(force: force));
  }

  Future<bool> _safeHasNetworkInterface() async {
    try {
      return await _networkMonitor.hasNetworkInterface();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeCanReachBackend() async {
    try {
      return await _backendProbe.canReachBackend(timeout: _backendTimeout);
    } catch (_) {
      return false;
    }
  }

  void _applyResult(int generation, ConnectivityStatus status) {
    if (generation != _checkGeneration) {
      return;
    }
    _setStatus(status);
  }

  void _setStatus(ConnectivityStatus status) {
    if (_isDisposed || _status == status) {
      return;
    }
    _status = status;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) _offlineRetryTimer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _requestFreshCheck(force: true);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _offlineRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_networkSubscription?.cancel());
    unawaited(_networkMonitor.dispose());
    super.dispose();
  }
}
