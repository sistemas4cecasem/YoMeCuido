import 'dart:async';

import '../../app/category_progress_controller.dart';
import '../../data/models/category_progress.dart';
import '../../data/models/pending_quiz_attempt.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/pending_quiz_attempt_repository.dart';
import 'connectivity_service.dart';

class PendingQuizAttemptSyncService {
  PendingQuizAttemptSyncService({
    required AuthRepository authRepository,
    required ConnectivityService connectivityService,
    required CategoryProgressController progressController,
    required PendingQuizAttemptRepository repository,
    Future<bool> Function(String uid)? canSyncUid,
  }) : _authRepository = authRepository,
       _connectivityService = connectivityService,
       _progressController = progressController,
       _repository = repository,
       _canSyncUid = canSyncUid;

  final AuthRepository _authRepository;
  final ConnectivityService _connectivityService;
  final CategoryProgressController _progressController;
  final PendingQuizAttemptRepository _repository;
  final Future<bool> Function(String uid)? _canSyncUid;

  final Set<String> _syncingAttemptIds = <String>{};
  final Set<String> _suspendedUids = <String>{};
  final Map<String, Completer<void>> _inFlight = <String, Completer<void>>{};
  StreamSubscription<void>? _authSubscription;
  bool _started = false;
  bool _disposed = false;
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
    final operation = _storageTail.then((_) => action());
    _storageTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<bool> syncSavedAttempt(String attemptId) async {
    await _storageTail;
    final attempts = await _repository.loadAll();
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
    _authSubscription = _authRepository.authStateChanges().listen((_) {
      unawaited(recoverCurrentUserInterruptedAttempts());
      unawaited(syncCurrentUserPendingAttempts());
    });
    unawaited(recoverCurrentUserInterruptedAttempts());
    unawaited(syncCurrentUserPendingAttempts());
  }

  Future<void> recoverCurrentUserInterruptedAttempts() async {
    if (_disposed) {
      return;
    }

    final uid = _authRepository.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (!await _canSync(uid)) return;

    final now = DateTime.now();
    final attempts = await _repository.loadAll();
    for (final attempt in attempts.where(
      (attempt) => attempt.uid == uid && attempt.isInterrupted,
    )) {
      if (_suspendedUids.contains(uid)) return;
      final finalized = attempt.finalized(completedAt: now);
      if (_connectivityService.status == ConnectivityStatus.online) {
        await _syncAttempt(finalized);
      } else {
        await savePending(finalized);
      }
    }
  }

  Future<void> syncCurrentUserPendingAttempts() async {
    if (_disposed || _connectivityService.status != ConnectivityStatus.online) {
      return;
    }

    final user = _authRepository.currentUser;
    final uid = user?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (!await _canSync(uid)) return;

    final attempts = await _repository.loadAll();
    for (final attempt in attempts.where(
      (attempt) => attempt.uid == uid && attempt.isPendingSync,
    )) {
      if (_suspendedUids.contains(uid)) return;
      await _syncAttempt(attempt);
    }
  }

  Future<bool> _syncAttempt(PendingQuizAttempt attempt) async {
    if (_disposed ||
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
    if (!await _canSync(attempt.uid)) return false;
    if (_suspendedUids.contains(attempt.uid) ||
        _syncingAttemptIds.contains(attempt.attemptId)) {
      return false;
    }

    _syncingAttemptIds.add(attempt.attemptId);
    final inFlightKey = '${attempt.uid}:${attempt.attemptId}';
    final completion = Completer<void>();
    _inFlight[inFlightKey] = completion;
    try {
      await savePending(
        attempt.copyWith(status: PendingQuizAttemptSyncStatus.syncing),
      );
      final synced = await _progressController.syncPendingQuizAttempt(attempt);
      if (_authRepository.currentUser?.uid.trim() != attempt.uid) {
        await savePending(attempt);
        return false;
      }
      if (synced && attempt.type == QuizAttemptType.exam) {
        final refreshed = await _progressController.refreshCategoryProgress(
          attempt.categoryId,
        );
        if (!refreshed) {
          await savePending(attempt);
          return false;
        }
      }
      if (synced) {
        await removeLocalAttempt(attempt.attemptId);
      } else {
        await savePending(attempt);
      }
      return synced;
    } catch (_) {
      await savePending(attempt);
      return false;
    } finally {
      _syncingAttemptIds.remove(attempt.attemptId);
      _inFlight.remove(inFlightKey);
      completion.complete();
    }
  }

  Future<bool> _canSync(String uid) async {
    if (_suspendedUids.contains(uid)) return false;
    final predicate = _canSyncUid;
    if (predicate == null) return true;
    try {
      final allowed = await predicate(uid);
      return allowed && !_suspendedUids.contains(uid);
    } catch (_) {
      return false;
    }
  }

  void _handleConnectivityChanged() {
    if (_connectivityService.status == ConnectivityStatus.online) {
      unawaited(syncCurrentUserPendingAttempts());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _connectivityService.removeListener(_handleConnectivityChanged);
    await _authSubscription?.cancel();
  }
}
