import 'dart:async';

import '../../app/category_progress_controller.dart';
import '../../data/models/category_progress.dart';
import '../../data/models/pending_quiz_attempt.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/pending_quiz_attempt_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import 'connectivity_service.dart';
import 'error_observation.dart';
import 'observability_service.dart';

class PendingQuizAttemptSyncService {
  PendingQuizAttemptSyncService({
    required AuthRepository authRepository,
    required ConnectivityService connectivityService,
    required CategoryProgressController progressController,
    required PendingQuizAttemptRepository repository,
    Future<bool> Function(String uid)? canSyncUid,
    ObservabilityService observabilityService =
        const NoOpObservabilityService(),
  }) : _authRepository = authRepository,
       _connectivityService = connectivityService,
       _progressController = progressController,
       _repository = repository,
       _canSyncUid = canSyncUid,
       _observability = SessionObservabilityService(observabilityService);

  final AuthRepository _authRepository;
  final ConnectivityService _connectivityService;
  final CategoryProgressController _progressController;
  final PendingQuizAttemptRepository _repository;
  final Future<bool> Function(String uid)? _canSyncUid;
  final ObservabilityService _observability;

  final Set<String> _syncingAttemptIds = <String>{};
  final Set<String> _suspendedUids = <String>{};
  final Map<String, Completer<void>> _inFlight = <String, Completer<void>>{};
  StreamSubscription<void>? _authSubscription;
  bool _started = false;
  bool _disposed = false;
  bool _authStreamFailed = false;
  int _authGeneration = 0;
  bool _recovering = false;
  bool _maintenanceRunning = false;
  bool _maintenanceRequested = false;
  bool _recoveryRequested = false;
  Future<void> _storageTail = Future<void>.value();

  Future<void> savePending(PendingQuizAttempt attempt) {
    return _serializeStorage(() => _repository.upsert(attempt));
  }

  Future<void> suspendForUser(String uid) async {
    _suspendedUids.add(uid);
    await Future.wait<void>([
      for (final entry in _inFlight.entries)
        if (entry.key.startsWith('$uid:')) entry.value.future,
    ]);
    await _storageTail;
  }

  Future<void> removeLocalAttempt(String attemptId) {
    return _serializeStorage(() => _repository.remove(attemptId));
  }

  Future<void> _serializeStorage(Future<void> Function() action) {
    final operation = _storageTail.then((_) async {
      try {
        await action();
      } catch (error) {
        observeUnexpectedError(
          _observability,
          error,
          operation: ObservabilityOperation.pendingStorage,
          category: ObservabilityCategory.storage,
          fallback: ObservabilityErrorCode.localWriteFailed,
        );
        rethrow;
      }
    });
    _storageTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<bool> syncSavedAttempt(String attemptId) async {
    final attempts = await _loadAttempts();
    if (attempts == null) return false;
    for (final attempt in attempts) {
      if (attempt.attemptId == attemptId && attempt.isPendingSync) {
        return _syncAttempt(attempt);
      }
    }
    return false;
  }

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _connectivityService.addListener(_handleConnectivityChanged);
    try {
      _authSubscription = _authRepository.authStateChanges().listen((_) {
        _authGeneration += 1;
        _authStreamFailed = false;
        _requestMaintenance(recover: true);
      }, onError: (Object error, StackTrace stack) => _handleAuthError(error));
    } catch (error) {
      _handleAuthError(error);
    }
    _requestMaintenance(recover: true);
  }

  Future<void> recoverCurrentUserInterruptedAttempts() async {
    if (_disposed || _authStreamFailed || _recovering) {
      return;
    }

    final uid = _authRepository.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return;
    }
    _recovering = true;
    try {
      final generation = _authGeneration;
      if (!await _canSync(uid) || !_isCurrentUser(uid, generation)) return;
      final now = DateTime.now();
      final attempts = await _loadAttempts();
      if (attempts == null) return;
      for (final attempt in attempts.where(
        (attempt) => attempt.uid == uid && attempt.isInterrupted,
      )) {
        if (!_isCurrentUser(uid, generation)) return;
        final finalized = attempt.finalized(completedAt: now);
        if (_connectivityService.status == ConnectivityStatus.online) {
          await _syncAttempt(finalized);
        } else if (!await _trySave(finalized)) {
          return;
        }
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> syncCurrentUserPendingAttempts() async {
    if (_disposed ||
        _authStreamFailed ||
        _connectivityService.status != ConnectivityStatus.online) {
      return;
    }

    final user = _authRepository.currentUser;
    final uid = user?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (!await _canSync(uid)) return;

    final generation = _authGeneration;
    final attempts = await _loadAttempts();
    if (attempts == null) return;
    for (final attempt in attempts.where(
      (attempt) => attempt.uid == uid && attempt.isPendingSync,
    )) {
      if (!_isCurrentUser(uid, generation)) return;
      await _syncAttempt(attempt);
    }
  }

  Future<bool> _syncAttempt(PendingQuizAttempt attempt) async {
    if (_disposed ||
        _authStreamFailed ||
        _suspendedUids.contains(attempt.uid) ||
        _syncingAttemptIds.contains(attempt.attemptId)) {
      return false;
    }
    if (_authRepository.currentUser?.uid.trim() != attempt.uid) {
      return false;
    }
    if (!attempt.isPendingSync) {
      return false;
    }
    final generation = _authGeneration;
    if (!await _canSync(attempt.uid)) return false;
    if (!_isCurrentUser(attempt.uid, generation) ||
        _syncingAttemptIds.contains(attempt.attemptId)) {
      return false;
    }

    _syncingAttemptIds.add(attempt.attemptId);
    final inFlightKey = '${attempt.uid}:${attempt.attemptId}';
    final completion = Completer<void>();
    _inFlight[inFlightKey] = completion;
    try {
      if (!await _trySave(
        attempt.copyWith(status: PendingQuizAttemptSyncStatus.syncing),
      )) {
        return false;
      }
      if (!_isCurrentUser(attempt.uid, generation)) {
        await _trySave(attempt);
        return false;
      }
      final synced = await _progressController.syncPendingQuizAttempt(attempt);
      if (!_isCurrentUser(attempt.uid, generation)) {
        await _trySave(attempt);
        return false;
      }
      if (synced && attempt.type == QuizAttemptType.exam) {
        final refreshed = await _progressController.refreshCategoryProgress(
          attempt.categoryId,
        );
        if (!refreshed) {
          await _trySave(attempt);
          return false;
        }
      }
      if (synced) {
        if (!_isCurrentUser(attempt.uid, generation)) {
          await _trySave(attempt);
          return false;
        }
        return await _tryRemove(attempt.attemptId);
      }
      await _trySave(attempt);
      return false;
    } catch (error) {
      observeUnexpectedError(
        _observability,
        error,
        operation: ObservabilityOperation.pendingSync,
        category: ObservabilityCategory.persistence,
      );
      await _trySave(attempt);
      return false;
    } finally {
      _syncingAttemptIds.remove(attempt.attemptId);
      _inFlight.remove(inFlightKey);
      completion.complete();
    }
  }

  Future<bool> _canSync(String uid) async {
    if (_disposed || _authStreamFailed || _suspendedUids.contains(uid)) {
      return false;
    }
    final predicate = _canSyncUid;
    if (predicate == null) return true;
    try {
      final allowed = await predicate(uid);
      return allowed && !_suspendedUids.contains(uid);
    } on UserProfileException catch (error) {
      if (error.reason == UserProfileFailureReason.unauthenticated ||
          error.reason == UserProfileFailureReason.accountDeleting) {
        return false;
      }
      final code = error.reason == UserProfileFailureReason.firebase
          ? classifyFirebaseErrorCode(error.firebaseCode)
          : ObservabilityErrorCode.unexpected;
      if (code != null) {
        unawaited(
          _observability.record(
            ObservabilityEvent(
              operation: ObservabilityOperation.pendingSync,
              code: code,
              category: ObservabilityCategory.persistence,
            ),
          ),
        );
      }
      return false;
    } catch (error) {
      observeUnexpectedError(
        _observability,
        error,
        operation: ObservabilityOperation.pendingSync,
        category: ObservabilityCategory.persistence,
      );
      return false;
    }
  }

  void _handleConnectivityChanged() {
    if (_connectivityService.status == ConnectivityStatus.online) {
      _requestMaintenance();
    }
  }

  bool _isCurrentUser(String uid, int generation) =>
      !_disposed &&
      !_authStreamFailed &&
      !_suspendedUids.contains(uid) &&
      generation == _authGeneration &&
      _authRepository.currentUser?.uid.trim() == uid;

  Future<List<PendingQuizAttempt>?> _loadAttempts() async {
    try {
      await _storageTail;
      return await _repository.loadAll();
    } catch (error) {
      observeUnexpectedError(
        _observability,
        error,
        operation: ObservabilityOperation.pendingStorage,
        category: ObservabilityCategory.storage,
        fallback: ObservabilityErrorCode.localReadFailed,
      );
      return null;
    }
  }

  Future<bool> _trySave(PendingQuizAttempt attempt) async {
    try {
      await savePending(attempt);
      return true;
    } catch (_) {
      // The storage boundary already recorded this failure; preserve the pending.
      return false;
    }
  }

  Future<bool> _tryRemove(String attemptId) async {
    try {
      await removeLocalAttempt(attemptId);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleAuthError(Object error) {
    _authGeneration += 1;
    _authStreamFailed = true;
    observeUnexpectedError(
      _observability,
      error,
      operation: ObservabilityOperation.authentication,
      category: ObservabilityCategory.authentication,
    );
  }

  void _requestMaintenance({bool recover = false}) {
    if (_disposed) return;
    _maintenanceRequested = true;
    _recoveryRequested = _recoveryRequested || recover;
    if (_maintenanceRunning) return;
    _maintenanceRunning = true;
    unawaited(_runMaintenance());
  }

  Future<void> _runMaintenance() async {
    try {
      do {
        _maintenanceRequested = false;
        final recover = _recoveryRequested;
        _recoveryRequested = false;
        try {
          if (recover) await recoverCurrentUserInterruptedAttempts();
          await syncCurrentUserPendingAttempts();
        } catch (error) {
          observeUnexpectedError(
            _observability,
            error,
            operation: ObservabilityOperation.recovery,
            category: ObservabilityCategory.persistence,
          );
        }
      } while (_maintenanceRequested && !_disposed);
    } finally {
      _maintenanceRunning = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _connectivityService.removeListener(_handleConnectivityChanged);
    try {
      await _authSubscription?.cancel();
    } catch (error) {
      observeUnexpectedError(
        _observability,
        error,
        operation: ObservabilityOperation.authentication,
        category: ObservabilityCategory.authentication,
      );
    }
  }
}
