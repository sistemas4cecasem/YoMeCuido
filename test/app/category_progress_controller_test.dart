import 'dart:async';

import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
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

    test('starts attempts and resets only current activity state', () async {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
      );

      await controller.markTheoryPageViewed(
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'what_is_digital_violence',
        totalPages: 4,
      );
      await controller.recordActivityAnswer(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: 'activity_1',
        answer: 'safe_action',
        isCorrect: true,
        correctAnswers: 1,
        totalActivities: 12,
      );

      await controller.startActivityAttempt(
        categoryId: _categoryId,
        lessonId: _lessonId,
        totalActivities: 12,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      expect(snapshot.viewedTheoryPageIds, <String>[
        'what_is_digital_violence',
      ]);
      expect(snapshot.completedActivityIds, isEmpty);
      expect(snapshot.correctAnswers, 0);
      expect(persistence.startAttemptCalls, hasLength(1));
    });

    test('records activity progress with stable activity ids', () async {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
      );

      await controller.recordActivityAnswer(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: 'activity_1',
        answer: 'control_passwords_threaten_messages',
        isCorrect: true,
        correctAnswers: 1,
        totalActivities: 12,
      );
      await controller.recordActivityAnswer(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: 'activity_1',
        answer: 'control_passwords_threaten_messages',
        isCorrect: true,
        correctAnswers: 1,
        totalActivities: 12,
      );

      final snapshot = controller.snapshotFor(_categoryId);
      expect(snapshot.completedActivityIds, <String>['activity_1']);
      expect(snapshot.completedActivities, 1);
      expect(persistence.answerCalls, hasLength(2));
      expect(persistence.answerCalls.last.activityId, 'activity_1');
      expect(persistence.answerCalls.last.isCompleted, isFalse);
    });

    test('marks completed answers with the final result', () async {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
      );

      await controller.recordActivityAnswer(
        categoryId: _categoryId,
        lessonId: _lessonId,
        activityId: 'activity_12',
        answer: 'emergency_help_safe_place',
        isCorrect: true,
        correctAnswers: 10,
        totalActivities: 12,
        result: QuizResult.fromScore(correctAnswers: 10, totalQuestions: 12),
      );

      final snapshot = controller.snapshotFor(_categoryId);
      expect(snapshot.hasResult, isTrue);
      expect(snapshot.result?.correctAnswers, 10);
      expect(persistence.answerCalls.single.isCompleted, isTrue);
      expect(persistence.answerCalls.single.correctAnswers, 10);
    });

    test('hydrates persisted progress without writing it back', () {
      final persistence = _FakeProgressPersistence();
      final controller = CategoryProgressController(
        persistence: persistence,
        currentUserIdProvider: () => 'uid-123',
      );

      controller.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[_completedRecord()],
      );

      final snapshot = controller.snapshotFor(_categoryId);
      expect(controller.hydrationStatus, ProgressHydrationStatus.loaded);
      expect(snapshot.status, CategoryProgressStatus.completed);
      expect(snapshot.viewedTheoryPageIds, <String>[
        'what_is_digital_violence',
        'control_is_not_care',
      ]);
      expect(snapshot.completedActivityIds, <String>[
        'activity_1',
        'activity_2',
      ]);
      expect(snapshot.attemptCount, 2);
      expect(snapshot.latestAnswers, contains('activity_1'));
      expect(snapshot.hasResult, isTrue);
      expect(snapshot.result?.correctAnswers, 2);
      expect(persistence.writeCallCount, 0);
    });

    test(
      'empty persisted progress leaves controller empty but loaded',
      () async {
        final persistence = _FakeProgressPersistence();
        final controller = CategoryProgressController(
          persistence: persistence,
          currentUserIdProvider: () => 'uid-123',
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

class _TheoryPageCall {
  const _TheoryPageCall({required this.pageId});

  final String pageId;
}

class _StartAttemptCall {
  const _StartAttemptCall();
}

class _AnswerCall {
  const _AnswerCall({
    required this.activityId,
    required this.correctAnswers,
    required this.isCompleted,
  });

  final String activityId;
  final int correctAnswers;
  final bool isCompleted;
}

class _FakeProgressPersistence implements CategoryProgressPersistence {
  final theoryPageCalls = <_TheoryPageCall>[];
  final startAttemptCalls = <_StartAttemptCall>[];
  final answerCalls = <_AnswerCall>[];
  final fetchCalls = <String>[];
  final recordsByUid = <String, List<CategoryProgressRecord>>{};
  final pendingFetchUids = <String>{};
  final _pendingFetches =
      <String, List<Completer<List<CategoryProgressRecord>>>>{};

  int get writeCallCount =>
      theoryPageCalls.length + startAttemptCalls.length + answerCalls.length;

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
    required int totalLessonPages,
    required int totalActivities,
  }) async {
    startAttemptCalls.add(const _StartAttemptCall());
  }

  @override
  Future<void> recordActivityAnswer({
    required String uid,
    required String categoryId,
    required String lessonId,
    required String activityId,
    required String answer,
    required bool isCorrect,
    required int correctAnswers,
    required int totalLessonPages,
    required int totalActivities,
    required bool isCompleted,
  }) async {
    answerCalls.add(
      _AnswerCall(
        activityId: activityId,
        correctAnswers: correctAnswers,
        isCompleted: isCompleted,
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
    completedActivityIds: const <String>['activity_1', 'activity_2'],
    correctAnswers: 2,
    totalLessonPages: 4,
    totalActivities: 12,
    attemptCount: 2,
    startedAt: now,
    lastActivityAt: now,
    completedAt: now,
    updatedAt: now,
    latestAnswers: <String, CategoryProgressAnswer>{
      'activity_1': CategoryProgressAnswer(
        answer: 'control_passwords_threaten_messages',
        isCorrect: true,
        answeredAt: now,
      ),
      'activity_2': CategoryProgressAnswer(
        answer: 'false',
        isCorrect: true,
        answeredAt: now,
      ),
    },
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
    correctAnswers: 0,
    totalLessonPages: 4,
    totalActivities: 12,
    attemptCount: 1,
    startedAt: now,
    lastActivityAt: null,
    completedAt: null,
    updatedAt: now,
    latestAnswers: const <String, CategoryProgressAnswer>{},
  );
}
