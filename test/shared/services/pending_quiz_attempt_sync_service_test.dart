import 'dart:async';
import 'dart:convert';

import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/pending_quiz_attempt.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/pending_quiz_attempt_repository.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:demo_yomecuido/shared/services/observability_service.dart';
import 'package:demo_yomecuido/shared/services/pending_quiz_attempt_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending attempt syncs once when online', () async {
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ]);
    final persistence = _FakeProgressPersistence();
    final auth = _FakeAuthRepository(uid: 'uid-a');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.syncCurrentUserPendingAttempts();

    expect(await pendingRepository.loadAll(), isEmpty);
    expect(persistence.completedAttemptIds, <String>['attempt-pending']);
  });

  test('sync failure keeps the pending attempt', () async {
    final pending = _pendingAttempt(uid: 'uid-a');
    final pendingRepository = _MemoryPendingQuizAttemptRepository([pending]);
    final persistence = _FakeProgressPersistence()..failComplete = true;
    final auth = _FakeAuthRepository(uid: 'uid-a');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.syncCurrentUserPendingAttempts();

    expect(
      (await pendingRepository.loadAll()).map((attempt) => attempt.attemptId),
      <String>[pending.attemptId],
    );
  });

  test('parallel online events do not duplicate sync', () async {
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ]);
    final persistence = _FakeProgressPersistence(delayCompletion: true);
    final auth = _FakeAuthRepository(uid: 'uid-a');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    final first = service.syncCurrentUserPendingAttempts();
    final second = service.syncCurrentUserPendingAttempts();
    for (var tick = 0; tick < 20 && !persistence.hasPendingDelay; tick++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(persistence.hasPendingDelay, isTrue);
    persistence.completeDelay();
    await Future.wait(<Future<void>>[first, second]);

    expect(persistence.completedAttemptIds, <String>['attempt-pending']);
  });

  test('different signed-in user does not sync another uid pending', () async {
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ]);
    final persistence = _FakeProgressPersistence();
    final auth = _FakeAuthRepository(uid: 'uid-b');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.syncCurrentUserPendingAttempts();

    expect(persistence.completedAttemptIds, isEmpty);
    expect(await pendingRepository.loadAll(), hasLength(1));
  });

  test('same user returning syncs their pending attempt', () async {
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ]);
    final persistence = _FakeProgressPersistence();
    final auth = _FakeAuthRepository(uid: 'uid-b');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.syncCurrentUserPendingAttempts();
    auth.emit('uid-a');
    await service.syncCurrentUserPendingAttempts();

    expect(await pendingRepository.loadAll(), isEmpty);
    expect(persistence.completedAttemptIds, <String>['attempt-pending']);
  });

  test(
    'pending exam keeps its 15 IDs across account switch and sync',
    () async {
      final pending = _pendingExam(uid: 'uid-a');
      final pendingRepository = _MemoryPendingQuizAttemptRepository([pending]);
      final persistence = _FakeProgressPersistence();
      final auth = _FakeAuthRepository(uid: 'uid-b');
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: pendingRepository,
        persistence: persistence,
      );

      await service.syncCurrentUserPendingAttempts();
      expect(await pendingRepository.loadAll(), hasLength(1));
      auth.emit('uid-a');
      await service.syncCurrentUserPendingAttempts();

      expect(await pendingRepository.loadAll(), isEmpty);
      expect(persistence.completedExamQuestionIds, pending.questionIds);
      expect(persistence.completedAttemptIds, ['exam-pending']);
    },
  );

  test('recovering interrupted attempt online syncs and removes it', () async {
    final interrupted = _pendingAttempt(
      uid: 'uid-a',
      status: PendingQuizAttemptSyncStatus.inProgress,
      completed: false,
    );
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      interrupted,
    ]);
    final persistence = _FakeProgressPersistence();
    final auth = _FakeAuthRepository(uid: 'uid-a');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.recoverCurrentUserInterruptedAttempts();
    await service.recoverCurrentUserInterruptedAttempts();

    expect(await pendingRepository.loadAll(), isEmpty);
    expect(persistence.completedAttemptIds, <String>['attempt-pending']);
  });

  test(
    'recovering interrupted attempt offline converts it to pending sync',
    () async {
      final pendingRepository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(
          uid: 'uid-a',
          status: PendingQuizAttemptSyncStatus.inProgress,
          completed: false,
        ),
      ]);
      final persistence = _FakeProgressPersistence();
      final auth = _FakeAuthRepository(uid: 'uid-a');
      final connectivity = await _offlineConnectivityService();
      addTearDown(connectivity.dispose);
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: pendingRepository,
        persistence: persistence,
      );

      await service.recoverCurrentUserInterruptedAttempts();

      final attempts = await pendingRepository.loadAll();
      expect(persistence.completedAttemptIds, isEmpty);
      expect(attempts, hasLength(1));
      expect(attempts.single.status, PendingQuizAttemptSyncStatus.pendingSync);
      expect(attempts.single.completedAt, isNotNull);
    },
  );

  test('recovery ignores interrupted attempt from another user', () async {
    final pendingRepository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(
        uid: 'uid-a',
        status: PendingQuizAttemptSyncStatus.inProgress,
        completed: false,
      ),
    ]);
    final persistence = _FakeProgressPersistence();
    final auth = _FakeAuthRepository(uid: 'uid-b');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: pendingRepository,
      persistence: persistence,
    );

    await service.recoverCurrentUserInterruptedAttempts();

    final attempts = await pendingRepository.loadAll();
    expect(persistence.completedAttemptIds, isEmpty);
    expect(attempts.single.status, PendingQuizAttemptSyncStatus.inProgress);
  });

  for (final error in [
    Exception('private-uid'),
    const FormatException('private', '{"answers":['),
  ]) {
    test(
      'read failure is safe and later retry keeps one attempt: ${error.runtimeType}',
      () async {
        final pending = _pendingAttempt(uid: 'uid-a');
        final repository = _MemoryPendingQuizAttemptRepository([pending])
          ..readError = error;
        final persistence = _FakeProgressPersistence();
        final auth = _FakeAuthRepository(uid: 'uid-a');
        final connectivity = await _onlineConnectivityService();
        addTearDown(connectivity.dispose);
        final observer = _Observer();
        final service = _syncService(
          auth: auth,
          connectivity: connectivity,
          pendingRepository: repository,
          persistence: persistence,
          observer: observer,
        );
        expect(await service.syncSavedAttempt(pending.attemptId), isFalse);
        await service.recoverCurrentUserInterruptedAttempts();
        await service.syncCurrentUserPendingAttempts();
        expect(repository._attempts.single, same(pending));
        expect(repository.upserts, 0);
        expect(persistence.completedAttemptIds, isEmpty);
        expect(observer.events, hasLength(1));
        expect(
          observer.events.single.operation,
          ObservabilityOperation.pendingStorage,
        );
        repository.readError = null;
        expect(await service.syncSavedAttempt(pending.attemptId), isTrue);
        expect(persistence.completedAttemptIds, [pending.attemptId]);
        expect(repository._attempts, isEmpty);
      },
    );
  }

  test(
    'invalid persisted JSON is not overwritten and repairs can sync',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final preferences = SharedPreferencesAsync();
      const raw = '[{"uid":"private-uid","answers":["private-answer"]';
      const key = 'pending_quiz_attempts_v1';
      await preferences.setString(key, raw);
      final repository = SharedPreferencesPendingQuizAttemptRepository(
        preferences: preferences,
      );
      final pending = _pendingAttempt(uid: 'uid-a');
      final auth = _FakeAuthRepository(uid: 'uid-a');
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final persistence = _FakeProgressPersistence();
      final observer = _Observer();
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
      );
      expect(await service.syncSavedAttempt(pending.attemptId), isFalse);
      await expectLater(service.savePending(pending), throwsFormatException);
      await expectLater(
        repository.removeForUid('uid-a'),
        throwsFormatException,
      );
      expect(await preferences.getString(key), raw);
      expect(persistence.completedAttemptIds, isEmpty);
      expect(observer.events.single.code, ObservabilityErrorCode.invalidData);
      await preferences.setString(key, jsonEncode([pending.toJson()]));
      expect(await service.syncSavedAttempt(pending.attemptId), isTrue);
      expect(persistence.completedAttemptIds, [pending.attemptId]);
    },
  );

  test('initial pending save failure prevents remote completion', () async {
    final repository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ])..failUpsertAt = 1;
    final persistence = _FakeProgressPersistence();
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final observer = _Observer();
    final service = _syncService(
      auth: _FakeAuthRepository(uid: 'uid-a'),
      connectivity: connectivity,
      pendingRepository: repository,
      persistence: persistence,
      observer: observer,
    );
    expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
    expect(persistence.completedAttemptIds, isEmpty);
    expect(
      repository._attempts.single.status,
      PendingQuizAttemptSyncStatus.pendingSync,
    );
    expect(
      observer.events.single.code,
      ObservabilityErrorCode.localWriteFailed,
    );
    expect(await service.syncSavedAttempt('attempt-pending'), isTrue);
    expect(persistence.completedAttemptIds, ['attempt-pending']);
  });

  test(
    'save after completion failure cannot escape and pending stays recoverable',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ])..failUpsertAt = 2;
      final persistence = _FakeProgressPersistence()
        ..completionError = StateError('private-answer');
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final observer = _Observer();
      final service = _syncService(
        auth: _FakeAuthRepository(uid: 'uid-a'),
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
      );
      expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
      expect(repository._attempts.single.isPendingSync, isTrue);
      expect(persistence.completedAttemptIds, isEmpty);
      expect(observer.events.map((e) => e.operation), [
        ObservabilityOperation.finalizeAttempt,
        ObservabilityOperation.pendingStorage,
      ]);
      persistence.completionError = null;
      expect(await service.syncSavedAttempt('attempt-pending'), isTrue);
      expect(persistence.completedAttemptIds, ['attempt-pending']);
      expect(repository._attempts, isEmpty);
    },
  );

  test(
    'removal failure does not report success or duplicate completion on retry',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ])..failRemove = true;
      final persistence = _FakeProgressPersistence();
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final observer = _Observer();
      final auth = _FakeAuthRepository(uid: 'uid-a');
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => auth.currentUser?.uid,
        observabilityService: observer,
      );
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
        controller: controller,
      );
      expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
      expect(repository._attempts.single.isPendingSync, isTrue);
      expect(controller.currentTotalPoints, 100);
      repository.failRemove = false;
      expect(await service.syncSavedAttempt('attempt-pending'), isTrue);
      expect(persistence.completedAttemptIds, ['attempt-pending']);
      expect(controller.currentTotalPoints, 100);
      expect(repository._attempts, isEmpty);
    },
  );

  test('failure while restoring inside sync catch is contained', () async {
    final repository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ])..failUpsertAt = 2;
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final persistence = _FakeProgressPersistence();
    final observer = _Observer();
    final controller = _FailingSyncController();
    final service = _syncService(
      auth: _FakeAuthRepository(uid: 'uid-a'),
      connectivity: connectivity,
      pendingRepository: repository,
      persistence: persistence,
      observer: observer,
      controller: controller,
    );
    expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
    expect(repository._attempts.single.isPendingSync, isTrue);
    expect(observer.events.map((e) => e.operation), [
      ObservabilityOperation.pendingSync,
      ObservabilityOperation.pendingStorage,
    ]);
    controller.fail = false;
    expect(await service.syncSavedAttempt('attempt-pending'), isTrue);
    expect(repository._attempts, isEmpty);
  });

  test(
    'offline concurrent recovery is bounded and survives a write failure',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(
          uid: 'uid-a',
          status: PendingQuizAttemptSyncStatus.inProgress,
          completed: false,
        ),
      ])..failUpsertAt = 1;
      final connectivity = await _offlineConnectivityService();
      addTearDown(connectivity.dispose);
      final persistence = _FakeProgressPersistence();
      final service = _syncService(
        auth: _FakeAuthRepository(uid: 'uid-a'),
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
      );
      await Future.wait([
        for (var i = 0; i < 10; i++)
          service.recoverCurrentUserInterruptedAttempts(),
      ]);
      expect(repository.upserts, 1);
      expect(
        repository._attempts.single.status,
        PendingQuizAttemptSyncStatus.inProgress,
      );
      await service.recoverCurrentUserInterruptedAttempts();
      expect(repository.upserts, 2);
      expect(repository._attempts.single.attemptId, 'attempt-pending');
      expect(repository._attempts.single.isPendingSync, isTrue);
      expect(persistence.completedAttemptIds, isEmpty);
    },
  );

  test(
    'Auth stream failure blocks stale user and next session recovers safely',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ])..readError = Exception('temporary-private');
      final auth = _FakeAuthRepository(uid: 'uid-a');
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final persistence = _FakeProgressPersistence();
      final observer = _Observer();
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
      );
      addTearDown(service.dispose);
      await service.start();
      await _drain();
      auth._controller.addError(StateError('private-uid'));
      await _drain();
      repository.readError = null;
      expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
      expect(persistence.completedAttemptIds, isEmpty);
      auth.emit('uid-b');
      await _drain();
      expect(persistence.completedAttemptIds, isEmpty);
      auth.emit('uid-a');
      await _drain();
      expect(persistence.completedAttemptIds, ['attempt-pending']);
      expect(repository._attempts, isEmpty);
      expect(
        observer.events.where(
          (e) => e.operation == ObservabilityOperation.authentication,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'background predicate failure is contained and later trigger recovers',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ]);
      final auth = _FakeAuthRepository(uid: 'uid-a');
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final persistence = _FakeProgressPersistence();
      final observer = _Observer()..fail = true;
      var failing = true;
      final service = _syncService(
        auth: auth,
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
        canSyncUid: (_) async {
          if (failing) throw StateError('private-path');
          return true;
        },
      );
      addTearDown(service.dispose);
      await service.start();
      await _drain();
      expect(repository._attempts, hasLength(1));
      expect(observer.events, hasLength(1));
      expect(persistence.completedAttemptIds, isEmpty);
      failing = false;
      auth.emit('uid-a');
      await _drain();
      expect(persistence.completedAttemptIds, ['attempt-pending']);
      expect(repository._attempts, isEmpty);
    },
  );

  test('UID change during pending read never syncs previous account', () async {
    final repository = _MemoryPendingQuizAttemptRepository([
      _pendingAttempt(uid: 'uid-a'),
    ])..readGate = Completer<void>();
    final auth = _FakeAuthRepository(uid: 'uid-a');
    final connectivity = await _onlineConnectivityService();
    addTearDown(connectivity.dispose);
    final persistence = _FakeProgressPersistence();
    final service = _syncService(
      auth: auth,
      connectivity: connectivity,
      pendingRepository: repository,
      persistence: persistence,
    );
    final sync = service.syncCurrentUserPendingAttempts();
    await _drain();
    auth.emit('uid-b');
    repository.readGate!.complete();
    await sync;
    expect(repository.upserts, 0);
    expect(persistence.completedAttemptIds, isEmpty);
    auth.emit('uid-a');
    await service.syncCurrentUserPendingAttempts();
    expect(persistence.completedAttemptIds, ['attempt-pending']);
  });

  test(
    'suspension waits for pending removal and concurrent retry is blocked',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ])..removeGate = Completer<void>();
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final persistence = _FakeProgressPersistence();
      final service = _syncService(
        auth: _FakeAuthRepository(uid: 'uid-a'),
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
      );
      final sync = service.syncSavedAttempt('attempt-pending');
      await _drain();
      final retry = service.syncSavedAttempt('attempt-pending');
      var suspended = false;
      final suspend = service
          .suspendForUser('uid-a')
          .then((_) => suspended = true);
      await _drain();
      expect(suspended, isFalse);
      repository.removeGate!.complete();
      expect(await sync, isTrue);
      expect(await retry, isFalse);
      await suspend;
      expect(persistence.completedAttemptIds, ['attempt-pending']);
      expect(repository._attempts, isEmpty);
    },
  );

  test(
    'connectivity recovery never finalizes a currently open activity',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository();
      final persistence = _FakeProgressPersistence();
      final probe = _SwitchableProbe();
      final connectivity = ConnectivityService(
        networkMonitor: _FakeNetworkInterfaceMonitor(),
        backendProbe: probe,
      );
      await connectivity.checkConnection();
      addTearDown(connectivity.dispose);
      final service = _syncService(
        auth: _FakeAuthRepository(uid: 'uid-a'),
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
      );
      addTearDown(service.dispose);
      await service.start();
      await _drain();
      final draft = _pendingAttempt(
        uid: 'uid-a',
        status: PendingQuizAttemptSyncStatus.inProgress,
        completed: false,
      );
      await service.savePending(draft);
      probe.reachable = true;
      await connectivity.checkConnection();
      await _drain();
      expect(repository._attempts.single, same(draft));
      expect(repository._attempts.single.completedAt, isNull);
      expect(persistence.completedAttemptIds, isEmpty);
    },
  );

  test(
    'expected completion unavailable restores pending without reporting',
    () async {
      final repository = _MemoryPendingQuizAttemptRepository([
        _pendingAttempt(uid: 'uid-a'),
      ]);
      final persistence = _FakeProgressPersistence()..failComplete = true;
      final connectivity = await _onlineConnectivityService();
      addTearDown(connectivity.dispose);
      final observer = _Observer();
      final service = _syncService(
        auth: _FakeAuthRepository(uid: 'uid-a'),
        connectivity: connectivity,
        pendingRepository: repository,
        persistence: persistence,
        observer: observer,
      );
      expect(await service.syncSavedAttempt('attempt-pending'), isFalse);
      expect(observer.events, isEmpty);
      expect(repository._attempts.single.isPendingSync, isTrue);
    },
  );
}

Future<void> _drain() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PendingQuizAttemptSyncService _syncService({
  required _FakeAuthRepository auth,
  required ConnectivityService connectivity,
  required PendingQuizAttemptRepository pendingRepository,
  required _FakeProgressPersistence persistence,
  ObservabilityService observer = const NoOpObservabilityService(),
  Future<bool> Function(String uid)? canSyncUid,
  CategoryProgressController? controller,
}) {
  final safeObserver = SessionObservabilityService(observer);
  return PendingQuizAttemptSyncService(
    observabilityService: safeObserver,
    canSyncUid: canSyncUid,
    authRepository: auth,
    connectivityService: connectivity,
    progressController:
        controller ??
        CategoryProgressController(
          observabilityService: safeObserver,
          persistence: persistence,
          currentUserIdProvider: () => auth.currentUser?.uid,
        ),
    repository: pendingRepository,
  );
}

Future<ConnectivityService> _onlineConnectivityService() async {
  final service = ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(),
    backendProbe: const _FakeBackendConnectivityProbe(reachable: true),
  );
  await service.checkConnection();
  return service;
}

Future<ConnectivityService> _offlineConnectivityService() async {
  final service = ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(),
    backendProbe: const _FakeBackendConnectivityProbe(reachable: false),
  );
  await service.checkConnection();
  return service;
}

PendingQuizAttempt _pendingAttempt({
  required String uid,
  PendingQuizAttemptSyncStatus status =
      PendingQuizAttemptSyncStatus.pendingSync,
  bool completed = true,
}) {
  final now = DateTime.utc(2026, 9, 22, 12);
  return PendingQuizAttempt(
    uid: uid,
    attemptId: 'attempt-pending',
    type: QuizAttemptType.activity,
    categoryId: 'category-a',
    lessonId: 'lesson-a',
    activityId: 'activity-a',
    examId: null,
    questionIds: const <String>['question-a'],
    answers: [
      CategoryProgressAnswer(
        questionId: 'question-a',
        answer: 'option-a',
        isCorrect: true,
        answeredAt: now,
      ),
    ],
    correctAnswers: 1,
    totalQuestions: 1,
    percentage: 100,
    totalActivities: 1,
    startedAt: now,
    completedAt: completed ? now.add(const Duration(minutes: 1)) : null,
    status: status,
  );
}

PendingQuizAttempt _pendingExam({required String uid}) {
  final now = DateTime.utc(2026, 9, 22, 12);
  final ids = [
    for (var index = 1; index <= 15; index += 1)
      'exam-question-${index.toString().padLeft(2, '0')}',
  ];
  return PendingQuizAttempt(
    uid: uid,
    attemptId: 'exam-pending',
    attemptNumber: 1,
    type: QuizAttemptType.exam,
    categoryId: 'category-a',
    lessonId: 'lesson-a',
    activityId: null,
    examId: 'lesson-a_final_exam',
    questionIds: ids,
    answers: [
      for (final id in ids)
        CategoryProgressAnswer(
          questionId: id,
          answer: 'option-a',
          isCorrect: ids.indexOf(id) < 12,
          answeredAt: now,
        ),
    ],
    correctAnswers: 12,
    totalQuestions: 15,
    percentage: 80,
    totalActivities: 6,
    startedAt: now,
    completedAt: now.add(const Duration(minutes: 1)),
    status: PendingQuizAttemptSyncStatus.pendingSync,
  );
}

class _MemoryPendingQuizAttemptRepository
    implements PendingQuizAttemptRepository {
  _MemoryPendingQuizAttemptRepository([List<PendingQuizAttempt>? attempts])
    : _attempts = <PendingQuizAttempt>[...?attempts];

  final List<PendingQuizAttempt> _attempts;
  Object? readError;
  int? failUpsertAt;
  int upserts = 0;
  bool failRemove = false;
  Completer<void>? readGate;
  Completer<void>? removeGate;

  @override
  Future<void> removeForUid(String uid) async {
    _attempts.removeWhere((attempt) => attempt.uid == uid);
  }

  @override
  Future<List<PendingQuizAttempt>> loadAll() async {
    await readGate?.future;
    if (readError != null) throw readError!;
    return List<PendingQuizAttempt>.unmodifiable(_attempts);
  }

  @override
  Future<void> remove(String attemptId) async {
    await removeGate?.future;
    if (failRemove) throw Exception('private-remove');
    _attempts.removeWhere((attempt) => attempt.attemptId == attemptId);
  }

  @override
  Future<void> upsert(PendingQuizAttempt attempt) async {
    upserts += 1;
    if (failUpsertAt == upserts) throw Exception('private-save');
    _attempts.removeWhere((item) => item.attemptId == attempt.attemptId);
    _attempts.add(attempt);
  }
}

class _FakeProgressPersistence implements CategoryProgressPersistence {
  _FakeProgressPersistence({this.delayCompletion = false});

  final bool delayCompletion;
  final completedAttemptIds = <String>[];
  List<String>? completedExamQuestionIds;
  bool failComplete = false;
  Object? completionError;
  Completer<void>? _delay;

  bool get hasPendingDelay => _delay != null;

  void completeDelay() {
    _delay?.complete();
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    int? reservedAttemptNumber,
    int? pointValue,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    if (delayCompletion) {
      _delay = Completer<void>();
      await _delay!.future;
    }
    if (failComplete) {
      throw const CategoryProgressException(
        CategoryProgressFailureReason.unavailable,
        operation: CategoryProgressFailureOperation.completeActivityAttempt,
      );
    }
    if (completionError != null) throw completionError!;
    completedAttemptIds.add(attemptId);
    return CompletedQuizAttemptPersistenceResult(
      attemptNumber: 1,
      answers: List<CategoryProgressAnswer>.unmodifiable(answers),
      correctAnswers: 1,
      totalQuestions: 1,
      percentage: 100,
      earnedPoints: 100,
      activityPoints: 100,
      questionScores: const <String, QuestionScoreRecord>{},
      totalPoints: 100,
    );
  }

  @override
  Future<CompletedQuizAttemptPersistenceResult> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    int? reservedAttemptNumber,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    completedAttemptIds.add(attemptId);
    completedExamQuestionIds = List<String>.of(questionIds);
    return CompletedQuizAttemptPersistenceResult(
      attemptNumber: reservedAttemptNumber ?? 1,
      answers: List<CategoryProgressAnswer>.unmodifiable(answers),
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      earnedPoints: 0,
      activityPoints: null,
      questionScores: const <String, QuestionScoreRecord>{},
      totalPoints: 0,
    );
  }

  @override
  Future<List<CategoryProgressRecord>> fetchAllProgress({required String uid}) {
    return Future<List<CategoryProgressRecord>>.value(
      const <CategoryProgressRecord>[],
    );
  }

  @override
  Future<void> markTheoryPageViewed({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String pageId,
    required int totalLessonPages,
    required int totalActivities,
  }) async {}
}

class _Observer implements ObservabilityService {
  final events = <ObservabilityEvent>[];
  bool fail = false;

  @override
  Future<void> record(ObservabilityEvent event) async {
    events.add(event);
    if (fail) throw StateError('private-observer');
  }
}

class _FailingSyncController extends CategoryProgressController {
  bool fail = true;

  @override
  Future<bool> syncPendingQuizAttempt(PendingQuizAttempt pending) async {
    if (fail) throw StateError('private-uid private-answer');
    return true;
  }
}

class _SwitchableProbe implements BackendConnectivityProbe {
  bool reachable = false;

  @override
  Future<bool> canReachBackend({required Duration timeout}) async => reachable;
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required String uid}) : _uid = uid;

  final _controller = StreamController<AuthUser?>.broadcast();
  String? _uid;

  void emit(String? uid) {
    _uid = uid;
    _controller.add(currentUser);
  }

  @override
  AuthUser? get currentUser {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    return AuthUser(uid: uid, email: '$uid@example.com', isEmailVerified: true);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String username,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async => emit(null);

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => true;

  @override
  Stream<bool> get onNetworkInterfaceChanged => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeBackendConnectivityProbe implements BackendConnectivityProbe {
  const _FakeBackendConnectivityProbe({required this.reachable});

  final bool reachable;

  @override
  Future<bool> canReachBackend({required Duration timeout}) async => reachable;
}
