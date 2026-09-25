import 'dart:async';

import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('network unavailable -> offline', () async {
    final network = _FakeNetworkInterfaceMonitor(hasInterface: false);
    final backend = _FakeBackendConnectivityProbe(<Future<bool> Function()>[
      () async => true,
    ]);
    final service = ConnectivityService(
      networkMonitor: network,
      backendProbe: backend,
    );
    addTearDown(service.dispose);

    final isOnline = await service.checkConnection(force: true);

    expect(isOnline, isFalse);
    expect(service.status, ConnectivityStatus.offline);
    expect(backend.callCount, 0);
  });

  test('network available + backend reachable -> online', () async {
    final service = _serviceWithBackendResponses(<Future<bool> Function()>[
      () async => true,
    ]);
    addTearDown(service.dispose);

    final isOnline = await service.checkConnection(force: true);

    expect(isOnline, isTrue);
    expect(service.status, ConnectivityStatus.online);
  });

  test('network available + backend timeout -> offline', () async {
    final service = _serviceWithBackendResponses(<Future<bool> Function()>[
      () async => false,
    ]);
    addTearDown(service.dispose);

    final isOnline = await service.checkConnection();

    expect(isOnline, isFalse);
    expect(service.status, ConnectivityStatus.offline);
  });

  test('backend error -> offline', () async {
    final service = _serviceWithBackendResponses(<Future<bool> Function()>[
      () async => throw StateError('backend unavailable'),
    ]);
    addTearDown(service.dispose);

    final isOnline = await service.checkConnection();

    expect(isOnline, isFalse);
    expect(service.status, ConnectivityStatus.offline);
  });

  test('recheck offline -> online', () async {
    final service = _serviceWithBackendResponses(<Future<bool> Function()>[
      () async => false,
      () async => true,
    ]);
    addTearDown(service.dispose);

    await service.checkConnection();
    final isOnline = await service.checkConnection(force: true);

    expect(isOnline, isTrue);
    expect(service.status, ConnectivityStatus.online);
  });

  test('recheck online -> offline', () async {
    final service = _serviceWithBackendResponses(<Future<bool> Function()>[
      () async => true,
      () async => false,
    ]);
    addTearDown(service.dispose);

    await service.checkConnection();
    final isOnline = await service.checkConnection(force: true);

    expect(isOnline, isFalse);
    expect(service.status, ConnectivityStatus.offline);
  });

  test(
    'simultaneous manual checks reuse the in-flight backend check',
    () async {
      final completer = Completer<bool>();
      final backend = _FakeBackendConnectivityProbe(<Future<bool> Function()>[
        () => completer.future,
      ]);
      final service = ConnectivityService(
        networkMonitor: _FakeNetworkInterfaceMonitor(),
        backendProbe: backend,
      );
      addTearDown(service.dispose);

      final first = service.checkConnection();
      final second = service.checkConnection();
      final third = service.checkConnection();

      await _pumpMicrotasks();
      expect(backend.callCount, 1);
      completer.complete(true);

      expect(await Future.wait(<Future<bool>>[first, second, third]), <bool>[
        true,
        true,
        true,
      ]);
      expect(service.status, ConnectivityStatus.online);
      expect(backend.callCount, 1);
    },
  );

  test('immediate repeated check reuses recent connectivity result', () async {
    final backend = _FakeBackendConnectivityProbe(<Future<bool> Function()>[
      () async => true,
      () async => false,
    ]);
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(),
      backendProbe: backend,
    );
    addTearDown(service.dispose);

    expect(await service.checkConnection(), isTrue);
    expect(await service.checkConnection(), isTrue);
    expect(backend.callCount, 1);
    expect(await service.checkConnection(force: true), isFalse);
    expect(backend.callCount, 2);
  });

  test(
    'multiple network events during a check settle on the latest result',
    () async {
      final firstCheck = Completer<bool>();
      final backend = _FakeBackendConnectivityProbe(<Future<bool> Function()>[
        () => firstCheck.future,
        () async => false,
      ]);
      final network = _FakeNetworkInterfaceMonitor();
      final service = ConnectivityService(
        networkMonitor: network,
        backendProbe: backend,
      );
      addTearDown(service.dispose);

      await service.start();
      expect(backend.callCount, 1);

      network.emit(false);
      network.emit(true);
      await Future<void>.delayed(Duration.zero);
      expect(backend.callCount, 1);

      firstCheck.complete(true);
      await firstCheck.future;
      await _pumpMicrotasks();

      expect(backend.callCount, 2);
      expect(service.status, ConnectivityStatus.offline);
    },
  );
}

ConnectivityService _serviceWithBackendResponses(
  List<Future<bool> Function()> responses,
) {
  return ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(),
    backendProbe: _FakeBackendConnectivityProbe(responses),
  );
}

Future<void> _pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  _FakeNetworkInterfaceMonitor({this.hasInterface = true});

  final _controller = StreamController<bool>.broadcast();
  bool hasInterface;

  void emit(bool value) {
    hasInterface = value;
    _controller.add(value);
  }

  @override
  Future<bool> hasNetworkInterface() async => hasInterface;

  @override
  Stream<bool> get onNetworkInterfaceChanged => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeBackendConnectivityProbe implements BackendConnectivityProbe {
  _FakeBackendConnectivityProbe(this._responses);

  final List<Future<bool> Function()> _responses;
  int callCount = 0;

  @override
  Future<bool> canReachBackend({required Duration timeout}) {
    callCount += 1;
    if (_responses.isEmpty) {
      return Future<bool>.value(false);
    }
    return _responses.removeAt(0)();
  }
}
