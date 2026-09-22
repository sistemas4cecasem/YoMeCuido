import 'dart:async';

import '../../app/category_progress_controller.dart';
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
  }) : _authRepository = authRepository,
       _connectivityService = connectivityService,
       _progressController = progressController,
       _repository = repository;

  final AuthRepository _authRepository;
  final ConnectivityService _connectivityService;
  final CategoryProgressController _progressController;
  final PendingQuizAttemptRepository _repository;

  final Set<String> _syncingAttemptIds = <String>{};
  StreamSubscription<void>? _authSubscription;
  bool _started = false;
  bool _disposed = false;

  Future<void> savePending(PendingQuizAttempt attempt) {
    return _repository.upsert(attempt);
  }

  Future<void> removeLocalAttempt(String attemptId) {
    return _repository.remove(attemptId);
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

    final now = DateTime.now();
    final attempts = await _repository.loadAll();
    for (final attempt in attempts.where(
      (attempt) => attempt.uid == uid && attempt.isInterrupted,
    )) {
      final finalized = attempt.finalized(completedAt: now);
      if (_connectivityService.status == ConnectivityStatus.online) {
        await _syncAttempt(finalized);
      } else {
        await _repository.upsert(finalized);
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

    final attempts = await _repository.loadAll();
    for (final attempt in attempts.where(
      (attempt) => attempt.uid == uid && attempt.isPendingSync,
    )) {
      await _syncAttempt(attempt);
    }
  }

  Future<void> _syncAttempt(PendingQuizAttempt attempt) async {
    if (_disposed || _syncingAttemptIds.contains(attempt.attemptId)) {
      return;
    }
    if (_authRepository.currentUser?.uid.trim() != attempt.uid) {
      return;
    }
    if (!attempt.isPendingSync) {
      return;
    }

    _syncingAttemptIds.add(attempt.attemptId);
    try {
      await _repository.upsert(
        attempt.copyWith(status: PendingQuizAttemptSyncStatus.syncing),
      );
      final synced = await _progressController.syncPendingQuizAttempt(attempt);
      if (_authRepository.currentUser?.uid.trim() != attempt.uid) {
        await _repository.upsert(attempt);
        return;
      }
      if (synced) {
        await _repository.remove(attempt.attemptId);
      } else {
        await _repository.upsert(attempt);
      }
    } catch (_) {
      await _repository.upsert(attempt);
    } finally {
      _syncingAttemptIds.remove(attempt.attemptId);
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
