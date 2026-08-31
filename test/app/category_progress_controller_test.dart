import 'dart:async';

import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/quiz_result.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryProgressController', () {
    test(
      'persists viewed theory pages by page id without duplicates',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );

        await controller.markTheoryPageViewed(
          categoryId: _categoryId,
          lessonId: _lessonId,
          pageId: 'what_is_digital_violence',
          totalPages: 4,
        );
        await controller.markTheoryPageViewed(
          categoryId: _categoryId,
          lessonId: _lessonId,
          pageId: 'what_is_digital_violence',
          totalPages: 4,
        );

        final snapshot = controller.snapshotFor(_categoryId);
        expect(snapshot.viewedTheoryPageIds, <String>[
          'what_is_digital_violence',
        ]);
        expect(persistence.theoryPageCalls, hasLength(1));
        expect(
          persistence.theoryPageCalls.single.pageId,
          'what_is_digital_violence',
        );
      },
    );

    test(
      'starts an activity attempt with independent id and question order',
      () {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );

        final attemptId = controller.startActivityAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          activityId: _activityId,
          questionIds: const <String>['question_07', 'question_02'],
          totalActivities: 6,
        );

        final attempt = controller.attemptFor(attemptId);
        final activityProgress = controller.activityProgressFor(
          categoryId: _categoryId,
          activityId: _activityId,
        );
        expect(attemptId, 'attempt_1');
        expect(attemptId, isNot(_activityId));
        expect(attempt?.type, QuizAttemptType.activity);
        expect(attempt?.activityId, _activityId);
        expect(attempt?.questionIds, <String>['question_07', 'question_02']);
        expect(activityProgress.status, ActivityProgressStatus.notStarted);
        expect(activityProgress.attemptCount, 0);
        expect(
          controller.snapshotFor(_categoryId).completedActivityIds,
          isEmpty,
        );
        expect(persistence.writeCallCount, 0);
      },
    );

    test(
      'records answers by question id without completing the activity',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );
        final attemptId = controller.startActivityAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          activityId: _activityId,
          questionIds: const <String>['question_01'],
          totalActivities: 6,
        );

        await controller.recordAnswer(
          categoryId: _categoryId,
          activityId: _activityId,
          attemptId: attemptId,
          questionId: 'question_01',
          answer: 'control_passwords_threaten_messages',
          isCorrect: true,
        );

        final attempt = controller.attemptFor(attemptId);
        expect(attempt?.answers, contains('question_01'));
        expect(
          attempt?.answers['question_01']?.answer,
          'control_passwords_threaten_messages',
        );
        expect(
          controller.snapshotFor(_categoryId).completedActivityIds,
          isEmpty,
        );
        expect(persistence.writeCallCount, 0);
      },
    );

    test(
      'completes activity and stores best percentage by activity id',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );
        final attemptId = controller.startActivityAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          activityId: _activityId,
          questionIds: const <String>['question_01', 'question_02'],
          totalActivities: 6,
        );

        await controller.completeActivityAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          activityId: _activityId,
          attemptId: attemptId,
          result: QuizResult.fromScore(correctAnswers: 1, totalQuestions: 2),
          totalActivities: 6,
        );

        final snapshot = controller.snapshotFor(_categoryId);
        final activityProgress = controller.activityProgressFor(
          categoryId: _categoryId,
          activityId: _activityId,
        );
        final attempt = controller.attemptFor(attemptId);
        expect(snapshot.completedActivityIds, <String>[_activityId]);
        expect(snapshot.completedActivityIds, isNot(contains('question_01')));
        expect(snapshot.completedActivities, 1);
        expect(activityProgress.status, ActivityProgressStatus.completed);
        expect(activityProgress.attemptCount, 1);
        expect(activityProgress.bestCorrectAnswers, 1);
        expect(activityProgress.bestPercentage, 50);
        expect(attempt?.correctAnswers, 1);
        expect(attempt?.totalQuestions, 2);
        expect(attempt?.percentage, 50);
        expect(attempt?.isCompleted, isTrue);
        expect(persistence.startAttemptCalls, isEmpty);
        expect(persistence.answerCalls, isEmpty);
        expect(persistence.completeCalls.single.activityId, _activityId);
      },
    );

    test('keeps retry history and preserves the best percentage', () async {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
        attemptIdGenerator: _sequentialAttemptIds(),
      );
      final firstAttemptId = controller.startActivityAttempt(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: _activityId,
        questionIds: const <String>['question_01', 'question_02'],
        totalActivities: 6,
      );
      await controller.completeActivityAttempt(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: _activityId,
        attemptId: firstAttemptId,
        result: QuizResult.fromScore(correctAnswers: 1, totalQuestions: 2),
        totalActivities: 6,
      );

      final secondAttemptId = controller.startActivityAttempt(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: _activityId,
        questionIds: const <String>['question_03', 'question_04'],
        totalActivities: 6,
      );
      await controller.completeActivityAttempt(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: _activityId,
        attemptId: secondAttemptId,
        result: QuizResult.fromScore(correctAnswers: 2, totalQuestions: 2),
        totalActivities: 6,
      );

      final activityProgress = controller.activityProgressFor(
        categoryId: _categoryId,
        activityId: _activityId,
      );
      expect(firstAttemptId, isNot(secondAttemptId));
      expect(activityProgress.attemptCount, 2);
      expect(activityProgress.bestCorrectAnswers, 2);
      expect(activityProgress.bestPercentage, 100);
      expect(controller.attemptFor(firstAttemptId)?.percentage, 50);
      expect(controller.attemptFor(secondAttemptId)?.percentage, 100);
      expect(persistence.startAttemptCalls, isEmpty);
      expect(persistence.completeCalls, hasLength(2));
    });

    test('hydrates persisted activity progress without writing it back', () {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      controller.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[_completedRecord()],
      );

      final snapshot = controller.snapshotFor(_categoryId);
      final activityProgress = controller.activityProgressFor(
        categoryId: _categoryId,
        activityId: _activityId,
      );
      expect(controller.hydrationStatus, ProgressHydrationStatus.loaded);
      expect(snapshot.status, CategoryProgressStatus.completed);
      expect(snapshot.viewedTheoryPageIds, <String>[
        'what_is_digital_violence',
        'control_is_not_care',
      ]);
      expect(snapshot.completedActivityIds, <String>[_activityId]);
      expect(activityProgress.attemptCount, 2);
      expect(activityProgress.bestPercentage, 80);
      expect(snapshot.hasResult, isTrue);
      expect(snapshot.result?.percentage, 80);
      expect(persistence.writeCallCount, 0);
    });

    test('ignores legacy completed ids that represented questions', () {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
        attemptIdGenerator: _sequentialAttemptIds(),
      );
      final now = DateTime.utc(2026, 8, 21, 20, 30);

      controller.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          CategoryProgressRecord(
            categoryId: _categoryId,
            lessonId: _lessonId,
            status: CategoryProgressStatus.inProgress,
            viewedLessonPageIds: const <String>[],
            completedActivityIds: const <String>['activity_1', _activityId],
            totalLessonPages: 4,
            totalActivities: 6,
            startedAt: now,
            lastActivityAt: now,
            completedAt: null,
            updatedAt: now,
            activities: const <String, ActivityProgressRecord>{},
            exams: const <String, ExamProgressRecord>{},
          ),
        ],
      );

      expect(controller.snapshotFor(_categoryId).completedActivityIds, <String>[
        _activityId,
      ]);
    });

    test('syncs stale theory totals with current local content', () {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
        attemptIdGenerator: _sequentialAttemptIds(),
      );
      final now = DateTime.utc(2026, 8, 31, 18);

      controller.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          CategoryProgressRecord(
            categoryId: _categoryId,
            lessonId: _lessonId,
            status: CategoryProgressStatus.completed,
            viewedLessonPageIds: const <String>[
              'what_is_digital_violence',
              'control_is_not_care',
              'consent_and_intimate_content',
              'how_to_act',
            ],
            completedActivityIds: const <String>[],
            totalLessonPages: 4,
            totalActivities: 12,
            startedAt: now,
            lastActivityAt: null,
            completedAt: now,
            updatedAt: now,
            activities: const <String, ActivityProgressRecord>{},
            exams: const <String, ExamProgressRecord>{},
          ),
        ],
      );

      controller.updateTheoryTotal(categoryId: _categoryId, totalPages: 6);
      controller.updateActivityTotal(
        categoryId: _categoryId,
        totalActivities: 6,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      expect(snapshot.totalTheoryPages, 6);
      expect(snapshot.viewedTheoryPages, 4);
      expect(snapshot.hasCompletedTheory, isFalse);
      expect(snapshot.totalActivities, 6);
      expect(snapshot.status, CategoryProgressStatus.inProgress);
      expect(snapshot.completedAt, isNull);
    });

    test(
      'completes exam attempts without marking a new activity as completed',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );
        final attemptId = controller.startExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          questionIds: const <String>['question_01', 'question_02'],
          totalActivities: 6,
        );

        await controller.recordAnswer(
          categoryId: _categoryId,
          examId: FinalExamConfigs.relationsViolence.id,
          attemptId: attemptId,
          questionId: 'question_01',
          answer: 'safe_option',
          isCorrect: true,
        );
        await controller.completeExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          attemptId: attemptId,
          result: QuizResult.fromScore(correctAnswers: 1, totalQuestions: 2),
          totalActivities: 6,
        );

        final snapshot = controller.snapshotFor(_categoryId);
        final examProgress = controller.examProgressFor(
          categoryId: _categoryId,
          examId: FinalExamConfigs.relationsViolence.id,
        );
        final attempt = controller.attemptFor(attemptId);

        expect(attempt?.type, QuizAttemptType.exam);
        expect(attempt?.activityId, isNull);
        expect(attempt?.examId, FinalExamConfigs.relationsViolence.id);
        expect(snapshot.completedActivityIds, isEmpty);
        expect(examProgress.status, ActivityProgressStatus.completed);
        expect(examProgress.attemptCount, 1);
        expect(examProgress.bestPercentage, 50);
        expect(persistence.startExamAttemptCalls, isEmpty);
        expect(persistence.answerCalls, isEmpty);
        expect(persistence.completeExamCalls.single.examId, attempt?.examId);
      },
    );

    test(
      'keeps exam retry history and preserves the best exam percentage',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );
        final firstAttemptId = controller.startExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          questionIds: const <String>['question_01', 'question_02'],
          totalActivities: 6,
        );
        await controller.completeExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          attemptId: firstAttemptId,
          result: QuizResult.fromScore(correctAnswers: 1, totalQuestions: 2),
          totalActivities: 6,
        );

        final secondAttemptId = controller.startExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          questionIds: const <String>['question_03', 'question_04'],
          totalActivities: 6,
        );
        await controller.completeExamAttempt(
          categoryId: _categoryId,
          lessonId: _lessonId,
          examId: FinalExamConfigs.relationsViolence.id,
          attemptId: secondAttemptId,
          result: QuizResult.fromScore(correctAnswers: 2, totalQuestions: 2),
          totalActivities: 6,
        );

        final examProgress = controller.examProgressFor(
          categoryId: _categoryId,
          examId: FinalExamConfigs.relationsViolence.id,
        );

        expect(firstAttemptId, isNot(secondAttemptId));
        expect(examProgress.attemptCount, 2);
        expect(examProgress.bestCorrectAnswers, 2);
        expect(examProgress.bestPercentage, 100);
        expect(controller.attemptFor(firstAttemptId)?.percentage, 50);
        expect(controller.attemptFor(secondAttemptId)?.percentage, 100);
        expect(persistence.startExamAttemptCalls, isEmpty);
        expect(persistence.completeExamCalls, hasLength(2));
      },
    );

    test(
      'empty persisted progress leaves controller empty but loaded',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
          attemptIdGenerator: _sequentialAttemptIds(),
        );

        await controller.loadPersistedProgressForUser('uid-123');

        expect(controller.hydrationStatus, ProgressHydrationStatus.loaded);
        expect(controller.hydratedUserId, 'uid-123');
        expect(controller.snapshotFor(_categoryId).overallPercentage, 0);
        expect(persistence.fetchCalls, <String>['uid-123']);
        expect(persistence.writeCallCount, 0);
      },
    );

    test('clear removes local progress without deleting remote data', () {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      controller.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[_completedRecord()],
      );
      controller.clearForSignedOutUser();

      final snapshot = controller.snapshotFor(_categoryId);
      expect(controller.hydrationStatus, ProgressHydrationStatus.notStarted);
      expect(snapshot.completedActivityIds, isEmpty);
      expect(snapshot.viewedTheoryPageIds, isEmpty);
      expect(snapshot.hasResult, isFalse);
      expect(persistence.writeCallCount, 0);
    });

    test('loading another user replaces the previous user progress', () async {
      var currentUid = 'uid-a';
      final persistence = _FakeProgressPersistence()
        ..recordsByUid['uid-a'] = <CategoryProgressRecord>[
          _completedRecord(categoryId: _categoryId),
        ]
        ..recordsByUid['uid-b'] = <CategoryProgressRecord>[
          _inProgressRecord(categoryId: 'other_category'),
        ];
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => currentUid,
        attemptIdGenerator: _sequentialAttemptIds(),
      );

      await controller.loadPersistedProgressForUser('uid-a');
      expect(controller.snapshotFor(_categoryId).hasResult, isTrue);

      currentUid = 'uid-b';
      await controller.loadPersistedProgressForUser('uid-b');

      expect(controller.hydratedUserId, 'uid-b');
      expect(controller.snapshotFor(_categoryId).hasResult, isFalse);
      expect(
        controller.snapshotFor('other_category').viewedTheoryPageIds,
        <String>['what_is_digital_violence'],
      );
    });

    test(
      'stale hydration response does not overwrite the active user',
      () async {
        var currentUid = 'uid-a';
        final persistence = _FakeProgressPersistence()
          ..pendingFetchUids.addAll(<String>['uid-a', 'uid-b']);
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => currentUid,
          attemptIdGenerator: _sequentialAttemptIds(),
        );

        final loadA = controller.loadPersistedProgressForUser('uid-a');
        currentUid = 'uid-b';
        final loadB = controller.loadPersistedProgressForUser('uid-b');

        persistence.completeFetch('uid-a', <CategoryProgressRecord>[
          _completedRecord(categoryId: _categoryId),
        ]);
        await loadA;
        expect(controller.hydratedUserId, 'uid-b');
        expect(controller.snapshotFor(_categoryId).hasResult, isFalse);

        persistence.completeFetch('uid-b', <CategoryProgressRecord>[
          _inProgressRecord(categoryId: 'other_category'),
        ]);
        await loadB;

        expect(controller.hydratedUserId, 'uid-b');
        expect(controller.snapshotFor(_categoryId).hasResult, isFalse);
        expect(
          controller.snapshotFor('other_category').viewedTheoryPageIds,
          <String>['what_is_digital_violence'],
        );
      },
    );
  });
}

const _categoryId = 'relations_violence_digital';
const _lessonId = 'relations_violence';
const _activityId = 'relations_violence_activity_01';

AttemptIdGenerator _sequentialAttemptIds() {
  var count = 0;
  return () {
    count += 1;
    return 'attempt_$count';
  };
}

class _TheoryPageCall {
  const _TheoryPageCall({required this.pageId});

  final String pageId;
}

class _StartAttemptCall {
  const _StartAttemptCall({
    required this.activityId,
    required this.attemptId,
    required this.questionIds,
  });

  final String activityId;
  final String attemptId;
  final List<String> questionIds;
}

class _StartExamAttemptCall {
  const _StartExamAttemptCall({
    required this.examId,
    required this.attemptId,
    required this.questionIds,
  });

  final String examId;
  final String attemptId;
  final List<String> questionIds;
}

class _AnswerCall {
  const _AnswerCall({
    required this.activityId,
    required this.examId,
    required this.attemptId,
    required this.questionId,
    required this.answer,
    required this.isCorrect,
  });

  final String? activityId;
  final String? examId;
  final String attemptId;
  final String questionId;
  final String answer;
  final bool isCorrect;
}

class _CompleteCall {
  const _CompleteCall({
    required this.activityId,
    required this.attemptId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
  });

  final String activityId;
  final String attemptId;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
}

class _CompleteExamCall {
  const _CompleteExamCall({
    required this.examId,
    required this.attemptId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
  });

  final String examId;
  final String attemptId;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
}

class _FakeProgressPersistence implements CategoryProgressPersistence {
  final theoryPageCalls = <_TheoryPageCall>[];
  final startAttemptCalls = <_StartAttemptCall>[];
  final startExamAttemptCalls = <_StartExamAttemptCall>[];
  final answerCalls = <_AnswerCall>[];
  final completeCalls = <_CompleteCall>[];
  final completeExamCalls = <_CompleteExamCall>[];
  final fetchCalls = <String>[];
  final recordsByUid = <String, List<CategoryProgressRecord>>{};
  final pendingFetchUids = <String>{};
  final _pendingFetches =
      <String, List<Completer<List<CategoryProgressRecord>>>>{};

  int get writeCallCount =>
      theoryPageCalls.length +
      startAttemptCalls.length +
      startExamAttemptCalls.length +
      answerCalls.length +
      completeCalls.length +
      completeExamCalls.length;

  void completeFetch(String uid, List<CategoryProgressRecord> records) {
    final pendingFetches = _pendingFetches[uid];
    if (pendingFetches == null || pendingFetches.isEmpty) {
      throw StateError('No pending fetch for $uid.');
    }
    pendingFetches.removeAt(0).complete(records);
  }

  @override
  Future<List<CategoryProgressRecord>> fetchAllProgress({required String uid}) {
    fetchCalls.add(uid);
    if (pendingFetchUids.contains(uid)) {
      final completer = Completer<List<CategoryProgressRecord>>();
      _pendingFetches.putIfAbsent(uid, () => []).add(completer);
      return completer.future;
    }

    final records = recordsByUid[uid];
    if (records != null) {
      return Future<List<CategoryProgressRecord>>.value(records);
    }

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
  }) async {
    theoryPageCalls.add(_TheoryPageCall(pageId: pageId));
  }

  @override
  Future<void> startActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    startAttemptCalls.add(
      _StartAttemptCall(
        activityId: activityId,
        attemptId: attemptId,
        questionIds: questionIds,
      ),
    );
  }

  @override
  Future<void> startExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required List<String> questionIds,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    startExamAttemptCalls.add(
      _StartExamAttemptCall(
        examId: examId,
        attemptId: attemptId,
        questionIds: questionIds,
      ),
    );
  }

  @override
  Future<void> recordAttemptAnswer({
    required String uid,
    required String categoryId,
    String? activityId,
    String? examId,
    required String attemptId,
    required String questionId,
    required String answer,
    required bool isCorrect,
  }) async {
    answerCalls.add(
      _AnswerCall(
        activityId: activityId,
        examId: examId,
        attemptId: attemptId,
        questionId: questionId,
        answer: answer,
        isCorrect: isCorrect,
      ),
    );
  }

  @override
  Future<void> completeActivityAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String attemptId,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    completeCalls.add(
      _CompleteCall(
        activityId: activityId,
        attemptId: attemptId,
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
        percentage: percentage,
      ),
    );
  }

  @override
  Future<void> completeExamAttempt({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String examId,
    required String attemptId,
    required DateTime startedAt,
    required List<String> questionIds,
    required Iterable<CategoryProgressAnswer> answers,
    required int correctAnswers,
    required int totalQuestions,
    required int percentage,
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    completeExamCalls.add(
      _CompleteExamCall(
        examId: examId,
        attemptId: attemptId,
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
        percentage: percentage,
      ),
    );
  }
}

CategoryProgressRecord _completedRecord({String categoryId = _categoryId}) {
  final now = DateTime.utc(2026, 8, 21, 20, 30);
  return CategoryProgressRecord(
    categoryId: categoryId,
    lessonId: _lessonId,
    status: CategoryProgressStatus.completed,
    viewedLessonPageIds: const <String>[
      'what_is_digital_violence',
      'control_is_not_care',
    ],
    completedActivityIds: const <String>[_activityId],
    totalLessonPages: 4,
    totalActivities: 1,
    startedAt: now,
    lastActivityAt: now,
    completedAt: now,
    updatedAt: now,
    activities: <String, ActivityProgressRecord>{
      _activityId: ActivityProgressRecord(
        activityId: _activityId,
        status: ActivityProgressStatus.completed,
        attemptCount: 2,
        bestCorrectAnswers: 4,
        bestTotalQuestions: 5,
        bestPercentage: 80,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      ),
    },
    exams: const <String, ExamProgressRecord>{},
  );
}

CategoryProgressRecord _inProgressRecord({required String categoryId}) {
  final now = DateTime.utc(2026, 8, 21, 20, 30);
  return CategoryProgressRecord(
    categoryId: categoryId,
    lessonId: _lessonId,
    status: CategoryProgressStatus.inProgress,
    viewedLessonPageIds: const <String>['what_is_digital_violence'],
    completedActivityIds: const <String>[],
    totalLessonPages: 4,
    totalActivities: 6,
    startedAt: now,
    lastActivityAt: null,
    completedAt: null,
    updatedAt: now,
    activities: const <String, ActivityProgressRecord>{},
    exams: const <String, ExamProgressRecord>{},
  );
}
