import 'dart:async';

import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/pending_quiz_attempt.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/pending_quiz_attempt_repository.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:demo_yomecuido/shared/services/pending_quiz_attempt_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

PendingQuizAttemptSyncService _syncService({
  required _FakeAuthRepository auth,
  required ConnectivityService connectivity,
  required _MemoryPendingQuizAttemptRepository pendingRepository,
  required _FakeProgressPersistence persistence,
}) {
  return PendingQuizAttemptSyncService(
    authRepository: auth,
    connectivityService: connectivity,
    progressController: CategoryProgressController(
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

  @override
  Future<void> removeForUid(String uid) async {
    _attempts.removeWhere((attempt) => attempt.uid == uid);
  }

  @override
  Future<List<PendingQuizAttempt>> loadAll() async =>
      List<PendingQuizAttempt>.unmodifiable(_attempts);

  @override
  Future<void> remove(String attemptId) async {
    _attempts.removeWhere((attempt) => attempt.attemptId == attemptId);
  }

  @override
  Future<void> upsert(PendingQuizAttempt attempt) async {
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
