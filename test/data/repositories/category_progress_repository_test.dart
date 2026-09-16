import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/firestore/educational_content_firestore_mapper.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryProgressRepository theory progress persistence', () {
    test('stores the first viewed page once without changing points', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore, totalPoints: 77);

      await repository.markTheoryPageViewed(
        uid: _uid,
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalLessonPages: 4,
        totalActivities: 6,
      );

      final progressData = await _progressData(firestore);
      final userData = await _userData(firestore);
      final activitySnapshot = await _activityDocument(firestore).get();

      expect(progressData['viewedLessonPageIds'], <String>['page_01']);
      expect(progressData['status'], CategoryProgressStatus.inProgress.name);
      expect(progressData['totalLessonPages'], 4);
      expect(progressData['totalActivities'], 6);
      expect(userData['totalPoints'], 77);
      expect(progressData.containsKey('activityPoints'), isFalse);
      expect(progressData.containsKey('questionScores'), isFalse);
      expect(activitySnapshot.exists, isFalse);
    });

    test('adds a second page without replacing the first one', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore);

      await repository.markTheoryPageViewed(
        uid: _uid,
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalLessonPages: 4,
        totalActivities: 6,
      );
      await repository.markTheoryPageViewed(
        uid: _uid,
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_02',
        totalLessonPages: 4,
        totalActivities: 6,
      );

      final progressData = await _progressData(firestore);

      expect(progressData['viewedLessonPageIds'], <String>[
        'page_01',
        'page_02',
      ]);
    });

    test('does not duplicate a viewed page when it is visited again', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore);

      for (var index = 0; index < 10; index += 1) {
        await repository.markTheoryPageViewed(
          uid: _uid,
          categoryId: _categoryId,
          lessonId: _lessonId,
          pageId: 'page_01',
          totalLessonPages: 4,
          totalActivities: 6,
        );
      }

      final progressData = await _progressData(firestore);

      expect(progressData['viewedLessonPageIds'], <String>['page_01']);
    });

    test('rehydrates the same theory progress in a new controller', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore);
      var currentUid = _uid;
      final firstController = CategoryProgressController(
        persistence: repository,
        currentUserIdProvider: () => currentUid,
      );

      await firstController.markTheoryPageViewed(
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalPages: 4,
      );
      await firstController.markTheoryPageViewed(
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_02',
        totalPages: 4,
      );

      final secondController = CategoryProgressController(
        persistence: repository,
        currentUserIdProvider: () => currentUid,
      );
      await secondController.loadPersistedProgressForUser(_uid);

      final snapshot = secondController.snapshotFor(_categoryId);
      expect(secondController.hydrationStatus, ProgressHydrationStatus.loaded);
      expect(snapshot.viewedTheoryPageIds, <String>['page_01', 'page_02']);
      expect(snapshot.viewedTheoryPages, 2);
      expect(snapshot.totalTheoryPages, 4);
    });

    test('keeps theory progress separated by uid', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore, uid: 'uid-a');
      await _seedUser(firestore, uid: 'uid-b');

      await repository.markTheoryPageViewed(
        uid: 'uid-a',
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalLessonPages: 4,
        totalActivities: 6,
      );
      await repository.markTheoryPageViewed(
        uid: 'uid-a',
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_02',
        totalLessonPages: 4,
        totalActivities: 6,
      );
      await repository.markTheoryPageViewed(
        uid: 'uid-b',
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalLessonPages: 4,
        totalActivities: 6,
      );

      final progressA = await _progressData(firestore, uid: 'uid-a');
      final progressB = await _progressData(firestore, uid: 'uid-b');

      expect(progressA['viewedLessonPageIds'], <String>['page_01', 'page_02']);
      expect(progressB['viewedLessonPageIds'], <String>['page_01']);
    });

    test('clearing memory on logout keeps Firestore progress intact', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore);
      var currentUid = _uid;
      final controller = CategoryProgressController(
        persistence: repository,
        currentUserIdProvider: () => currentUid,
      );

      await controller.markTheoryPageViewed(
        categoryId: _categoryId,
        lessonId: _lessonId,
        pageId: 'page_01',
        totalPages: 4,
      );
      currentUid = '';
      controller.clearForSignedOutUser();

      expect(controller.snapshotFor(_categoryId).viewedTheoryPageIds, isEmpty);
      expect((await _progressData(firestore))['viewedLessonPageIds'], <String>[
        'page_01',
      ]);

      currentUid = _uid;
      await controller.loadPersistedProgressForUser(_uid);

      expect(controller.snapshotFor(_categoryId).viewedTheoryPageIds, <String>[
        'page_01',
      ]);
    });

    test(
      'preserves concurrent page additions from separate instances',
      () async {
        final firestore = FakeFirebaseFirestore();
        final firstRepository = CategoryProgressRepository(
          firestore: firestore,
        );
        final secondRepository = CategoryProgressRepository(
          firestore: firestore,
        );
        await _seedUser(firestore);
        await firstRepository.markTheoryPageViewed(
          uid: _uid,
          categoryId: _categoryId,
          lessonId: _lessonId,
          pageId: 'page_00',
          totalLessonPages: 4,
          totalActivities: 6,
        );

        await Future.wait(<Future<void>>[
          firstRepository.markTheoryPageViewed(
            uid: _uid,
            categoryId: _categoryId,
            lessonId: _lessonId,
            pageId: 'page_01',
            totalLessonPages: 4,
            totalActivities: 6,
          ),
          secondRepository.markTheoryPageViewed(
            uid: _uid,
            categoryId: _categoryId,
            lessonId: _lessonId,
            pageId: 'page_02',
            totalLessonPages: 4,
            totalActivities: 6,
          ),
        ]);

        final progressData = await _progressData(firestore);

        expect(
          progressData['viewedLessonPageIds'],
          containsAll(<String>['page_00', 'page_01', 'page_02']),
        );
        expect(progressData['viewedLessonPageIds'], hasLength(3));
      },
    );
  });

  group('CategoryProgressRepository activity scoring transaction', () {
    test('consolidates the complete 61 point scenario atomically', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore, totalPoints: 200);
      await _seedQuestions(firestore);

      final first = await _completeActivity(
        repository,
        attemptId: 'attempt_a',
        correctQuestionIds: _ids(1, 5),
      );
      final second = await _completeActivity(
        repository,
        attemptId: 'attempt_b',
        correctQuestionIds: _ids(1, 7),
      );
      final third = await _completeActivity(
        repository,
        attemptId: 'attempt_c',
        correctQuestionIds: _ids(1, 8),
      );
      final fourth = await _completeActivity(
        repository,
        attemptId: 'attempt_d',
        correctQuestionIds: _ids(1, 10),
      );

      final activityData = await _activityData(firestore);
      final userData = await _userData(firestore);
      final leaderboardData = await _leaderboardData(firestore);
      final questionScores = activityData['questionScores'] as Map;
      final fourthAttempt = await _activityAttemptData(firestore, 'attempt_d');

      expect(first.attemptNumber, 1);
      expect(first.correctAnswers, 5);
      expect(first.earnedPoints, 50);
      expect(first.activityPoints, 50);
      expect(first.totalPoints, 250);
      expect(second.attemptNumber, 2);
      expect(second.earnedPoints, 10);
      expect(second.activityPoints, 60);
      expect(second.totalPoints, 260);
      expect(third.attemptNumber, 3);
      expect(third.earnedPoints, 1);
      expect(third.activityPoints, 61);
      expect(third.totalPoints, 261);
      expect(fourth.attemptNumber, 4);
      expect(fourth.correctAnswers, 10);
      expect(fourth.percentage, 100);
      expect(fourth.earnedPoints, 0);
      expect(fourth.activityPoints, 61);
      expect(fourth.totalPoints, 261);
      expect(activityData['attemptCount'], 4);
      expect(activityData['activityPoints'], 61);
      expect(activityData['bestPercentage'], 100);
      expect(userData['totalPoints'], 261);
      expect(leaderboardData['username'], 'Persona');
      expect(leaderboardData['totalPoints'], 261);
      expect(leaderboardData.containsKey('email'), isFalse);
      expect(leaderboardData.containsKey('role'), isFalse);
      expect(questionScores['q01']['pointsAwarded'], 10);
      expect(questionScores['q01']['awardedAttempt'], 1);
      expect(questionScores['q06']['pointsAwarded'], 5);
      expect(questionScores['q06']['awardedAttempt'], 2);
      expect(questionScores['q08']['pointsAwarded'], 1);
      expect(questionScores['q08']['awardedAttempt'], 3);
      expect(questionScores['q09']['pointsAwarded'], 0);
      expect(questionScores['q09']['awardedAttempt'], isNull);
      expect(fourthAttempt['earnedPoints'], 0);
      expect(fourthAttempt['correctAnswers'], 10);
      expect(fourthAttempt['percentage'], 100);
      expect(fourthAttempt['answers']['q01']['pointsEarned'], 0);
    });

    test(
      'awards 100 points for ten correct answers on the first attempt',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = CategoryProgressRepository(firestore: firestore);
        await _seedUser(firestore);
        await _seedQuestions(firestore);

        final result = await _completeActivity(
          repository,
          attemptId: 'attempt_perfect',
          correctQuestionIds: _ids(1, 10),
        );

        final activityData = await _activityData(firestore);
        final userData = await _userData(firestore);

        expect(result.earnedPoints, 100);
        expect(result.totalPoints, 100);
        expect(activityData['activityPoints'], 100);
        expect(userData['totalPoints'], 100);
      },
    );

    test(
      'completes an activity using submitted scoring when remote questions are not seeded',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = CategoryProgressRepository(firestore: firestore);
        await _seedUser(firestore);

        final result = await _completeActivity(
          repository,
          attemptId: 'attempt_without_remote_questions',
          correctQuestionIds: _ids(1, 8),
        );

        final activityData = await _activityData(firestore);
        final userData = await _userData(firestore);

        expect(result.correctAnswers, 8);
        expect(result.earnedPoints, 80);
        expect(activityData['bestCorrectAnswers'], 8);
        expect(activityData['activityPoints'], 80);
        expect(userData['totalPoints'], 80);
      },
    );

    test('registers all incorrect attempts without awarding points', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore);
      await _seedQuestions(firestore);

      for (var attempt = 1; attempt <= 3; attempt += 1) {
        final result = await _completeActivity(
          repository,
          attemptId: 'attempt_$attempt',
          correctQuestionIds: const <String>{},
        );
        expect(result.earnedPoints, 0);
      }
      final fourth = await _completeActivity(
        repository,
        attemptId: 'attempt_4',
        correctQuestionIds: _ids(1, 10),
      );

      final activityData = await _activityData(firestore);
      final userData = await _userData(firestore);

      expect(fourth.attemptNumber, 4);
      expect(fourth.correctAnswers, 10);
      expect(fourth.percentage, 100);
      expect(fourth.earnedPoints, 0);
      expect(fourth.totalPoints, 0);
      expect(activityData['attemptCount'], 4);
      expect(activityData['activityPoints'], 0);
      expect(userData['totalPoints'], 0);
    });

    test(
      'derives attempt number and scoring from persisted progress',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = CategoryProgressRepository(firestore: firestore);
        await _seedUser(firestore, totalPoints: 40);
        await _seedQuestions(firestore);
        await _activityDocument(firestore).set({
          'activityId': _activityId,
          'status': ActivityProgressStatus.completed.firestoreValue,
          'attemptCount': 2,
          'activityPoints': 10,
          'questionScores': {
            'q01': const QuestionScoreRecord(
              questionId: 'q01',
              pointsAwarded: 10,
              awardedAttempt: 1,
            ).toFirestore(),
          },
          'bestCorrectAnswers': 1,
          'bestTotalQuestions': 10,
          'bestPercentage': 10,
          'lastAttemptAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
          'completedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        });

        final result = await _completeActivity(
          repository,
          attemptId: 'attempt_from_persisted',
          correctQuestionIds: <String>{'q01', 'q02'},
        );

        final activityData = await _activityData(firestore);
        final userData = await _userData(firestore);
        final questionScores = activityData['questionScores'] as Map;

        expect(result.attemptNumber, 3);
        expect(result.earnedPoints, 1);
        expect(result.totalPoints, 41);
        expect(activityData['attemptCount'], 3);
        expect(activityData['activityPoints'], 11);
        expect(userData['totalPoints'], 41);
        expect(questionScores['q01']['pointsAwarded'], 10);
        expect(questionScores['q01']['awardedAttempt'], 1);
        expect(questionScores['q02']['pointsAwarded'], 1);
        expect(questionScores['q02']['awardedAttempt'], 3);
      },
    );

    test(
      'does not duplicate attempts or points for the same attempt id',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = CategoryProgressRepository(firestore: firestore);
        await _seedUser(firestore);
        await _seedQuestions(firestore);

        final first = await _completeActivity(
          repository,
          attemptId: 'attempt_once',
          correctQuestionIds: _ids(1, 10),
        );
        final second = await _completeActivity(
          repository,
          attemptId: 'attempt_once',
          correctQuestionIds: _ids(1, 10),
        );

        final activityData = await _activityData(firestore);
        final userData = await _userData(firestore);

        expect(first.earnedPoints, 100);
        expect(second.attemptNumber, 1);
        expect(second.earnedPoints, 100);
        expect(second.totalPoints, 100);
        expect(activityData['attemptCount'], 1);
        expect(activityData['activityPoints'], 100);
        expect(userData['totalPoints'], 100);
      },
    );

    test('finalizing an exam does not change totalPoints', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CategoryProgressRepository(firestore: firestore);
      await _seedUser(firestore, totalPoints: 300);

      final result = await repository.completeExamAttempt(
        uid: _uid,
        categoryId: _categoryId,
        lessonId: _lessonId,
        examId: _examId,
        attemptId: 'exam_attempt',
        startedAt: DateTime.utc(2026, 9, 10),
        questionIds: _ids(1, 10).toList(),
        answers: _answers(_ids(1, 10)),
        correctAnswers: 10,
        totalQuestions: 10,
        percentage: 100,
        totalLessonPages: 4,
        totalActivities: 6,
      );

      final userData = await _userData(firestore);
      final examAttempt = await _examAttemptData(firestore, 'exam_attempt');

      expect(result.earnedPoints, 0);
      expect(result.totalPoints, 300);
      expect(userData['totalPoints'], 300);
      expect(examAttempt['earnedPoints'], 0);
    });

    test(
      'keeps totalPoints equal to the sum of multiple activity points',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = CategoryProgressRepository(firestore: firestore);
        await _seedUser(firestore);
        await _seedQuestions(firestore, activityId: _activityId);
        await _seedQuestions(
          firestore,
          activityId: _secondActivityId,
          questionIds: _prefixedIds('b'),
        );
        await _seedQuestions(
          firestore,
          activityId: _thirdActivityId,
          questionIds: _prefixedIds('c'),
        );

        for (final attempt in [
          ('attempt_a_1', _ids(1, 5)),
          ('attempt_a_2', _ids(1, 7)),
          ('attempt_a_3', _ids(1, 8)),
          ('attempt_a_4', _ids(1, 10)),
        ]) {
          await _completeActivity(
            repository,
            attemptId: attempt.$1,
            correctQuestionIds: attempt.$2,
          );
        }
        final secondActivity = await _completeActivity(
          repository,
          activityId: _secondActivityId,
          attemptId: 'attempt_b_1',
          questionIds: _prefixedIds('b').toList(),
          correctQuestionIds: _prefixedIds('b', end: 8),
        );
        final thirdActivity = await _completeActivity(
          repository,
          activityId: _thirdActivityId,
          attemptId: 'attempt_c_1',
          questionIds: _prefixedIds('c').toList(),
          correctQuestionIds: _prefixedIds('c'),
        );

        final firstActivityData = await _activityData(firestore);
        final secondActivityData = await _activityData(
          firestore,
          activityId: _secondActivityId,
        );
        final thirdActivityData = await _activityData(
          firestore,
          activityId: _thirdActivityId,
        );
        final userData = await _userData(firestore);

        expect(firstActivityData['activityPoints'], 61);
        expect(secondActivity.earnedPoints, 80);
        expect(secondActivity.totalPoints, 141);
        expect(secondActivityData['activityPoints'], 80);
        expect(thirdActivity.earnedPoints, 100);
        expect(thirdActivity.totalPoints, 241);
        expect(thirdActivityData['activityPoints'], 100);
        expect(userData['totalPoints'], 241);
        expect(
          _sumActivityPoints([
            firstActivityData,
            secondActivityData,
            thirdActivityData,
          ]),
          userData['totalPoints'],
        );
      },
    );
  });
}

const _uid = 'uid-123';
const _categoryId = 'relations_violence_digital';
const _lessonId = 'relations_violence';
const _activityId = 'relations_violence_activity_01';
const _secondActivityId = 'relations_violence_activity_02';
const _thirdActivityId = 'relations_violence_activity_03';
const _examId = 'relations_violence_final_exam';

Future<CompletedQuizAttemptPersistenceResult> _completeActivity(
  CategoryProgressRepository repository, {
  String activityId = _activityId,
  List<String>? questionIds,
  required String attemptId,
  required Set<String> correctQuestionIds,
}) {
  final resolvedQuestionIds = questionIds ?? _ids(1, 10).toList();
  return repository.completeActivityAttempt(
    uid: _uid,
    categoryId: _categoryId,
    lessonId: _lessonId,
    activityId: activityId,
    attemptId: attemptId,
    startedAt: DateTime.utc(2026, 9, 10),
    questionIds: resolvedQuestionIds,
    answers: _answers(correctQuestionIds, questionIds: resolvedQuestionIds),
    totalLessonPages: 4,
    totalActivities: 6,
  );
}

List<CategoryProgressAnswer> _answers(
  Set<String> correctQuestionIds, {
  List<String>? questionIds,
}) {
  return (questionIds ?? _ids(1, 10))
      .map((questionId) {
        return CategoryProgressAnswer(
          questionId: questionId,
          answer: correctQuestionIds.contains(questionId)
              ? 'correct'
              : 'incorrect',
          isCorrect: correctQuestionIds.contains(questionId),
          answeredAt: DateTime.utc(2026, 9, 10),
        );
      })
      .toList(growable: false);
}

Set<String> _ids(int start, int end) {
  return {
    for (var index = start; index <= end; index += 1)
      'q${index.toString().padLeft(2, '0')}',
  };
}

Set<String> _prefixedIds(String prefix, {int start = 1, int end = 10}) {
  return {
    for (var index = start; index <= end; index += 1)
      '$prefix${index.toString().padLeft(2, '0')}',
  };
}

Future<void> _seedUser(
  FakeFirebaseFirestore firestore, {
  String uid = _uid,
  int totalPoints = 0,
}) {
  return _userDocument(firestore, uid: uid).set({
    'username': 'Persona',
    'usernameNormalized': 'persona',
    'email': 'persona@yomecuido.test',
    'role': 'user',
    'totalPoints': totalPoints,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
  });
}

Future<void> _seedQuestions(
  FakeFirebaseFirestore firestore, {
  String activityId = _activityId,
  Set<String>? questionIds,
}) async {
  for (final questionId in questionIds ?? _ids(1, 10)) {
    await firestore
        .collection('categories')
        .doc(_categoryId)
        .collection('questions')
        .doc(questionId)
        .set(
          EducationalContentFirestoreMapper.questionToMap(
            QuizQuestion(
              id: questionId,
              categoryId: _categoryId,
              activityId: activityId,
              type: QuestionType.multipleChoice,
              statement: 'Pregunta $questionId',
              options: const <QuizOption>[
                QuizOption(id: 'correct', text: 'Correcta'),
                QuizOption(id: 'incorrect', text: 'Incorrecta'),
              ],
              correctAnswer: 'correct',
              acceptedAnswers: const <String>['correct'],
              feedback: 'Retroalimentación.',
              capacity: 'reconocer',
              difficulty: 'básica',
            ),
          ),
        );
  }
}

Future<Map<String, dynamic>> _activityData(
  FakeFirebaseFirestore firestore, {
  String activityId = _activityId,
}) async {
  final snapshot = await _activityDocument(
    firestore,
    activityId: activityId,
  ).get();
  return snapshot.data()!;
}

Future<Map<String, dynamic>> _activityAttemptData(
  FakeFirebaseFirestore firestore,
  String attemptId,
) async {
  final snapshot = await _activityDocument(
    firestore,
  ).collection('attempts').doc(attemptId).get();
  return snapshot.data()!;
}

Future<Map<String, dynamic>> _examAttemptData(
  FakeFirebaseFirestore firestore,
  String attemptId,
) async {
  final snapshot = await _userDocument(firestore)
      .collection('categoryProgress')
      .doc(_categoryId)
      .collection('exams')
      .doc(_examId)
      .collection('attempts')
      .doc(attemptId)
      .get();
  return snapshot.data()!;
}

Future<Map<String, dynamic>> _progressData(
  FakeFirebaseFirestore firestore, {
  String uid = _uid,
}) async {
  final snapshot = await _progressDocument(firestore, uid: uid).get();
  return snapshot.data()!;
}

Future<Map<String, dynamic>> _userData(FakeFirebaseFirestore firestore) async {
  final snapshot = await _userDocument(firestore).get();
  return snapshot.data()!;
}

Future<Map<String, dynamic>> _leaderboardData(
  FakeFirebaseFirestore firestore,
) async {
  final snapshot = await firestore.collection('leaderboard').doc(_uid).get();
  return snapshot.data()!;
}

DocumentReference<Map<String, dynamic>> _userDocument(
  FakeFirebaseFirestore firestore, {
  String uid = _uid,
}) {
  return firestore.collection(UserProfileRepository.usersCollection).doc(uid);
}

DocumentReference<Map<String, dynamic>> _progressDocument(
  FakeFirebaseFirestore firestore, {
  String uid = _uid,
}) {
  return _userDocument(
    firestore,
    uid: uid,
  ).collection('categoryProgress').doc(_categoryId);
}

DocumentReference<Map<String, dynamic>> _activityDocument(
  FakeFirebaseFirestore firestore, {
  String activityId = _activityId,
}) {
  return _progressDocument(firestore).collection('activities').doc(activityId);
}

int _sumActivityPoints(Iterable<Map<String, dynamic>> activities) {
  return activities.fold<int>(
    0,
    (total, activity) => total + (activity['activityPoints'] as int),
  );
}
