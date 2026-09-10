import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/firestore/educational_content_firestore_mapper.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      final questionScores = activityData['questionScores'] as Map;
      final fourthAttempt = await _activityAttemptData(firestore, 'attempt_d');

      expect(first.attemptNumber, 1);
      expect(first.correctAnswers, 5);
      expect(first.earnedPoints, 50);
      expect(first.activityPoints, 50);
      expect(second.attemptNumber, 2);
      expect(second.earnedPoints, 10);
      expect(second.activityPoints, 60);
      expect(third.attemptNumber, 3);
      expect(third.earnedPoints, 1);
      expect(third.activityPoints, 61);
      expect(fourth.attemptNumber, 4);
      expect(fourth.correctAnswers, 10);
      expect(fourth.percentage, 100);
      expect(fourth.earnedPoints, 0);
      expect(fourth.activityPoints, 61);
      expect(activityData['attemptCount'], 4);
      expect(activityData['activityPoints'], 61);
      expect(activityData['bestPercentage'], 100);
      expect(userData['totalPoints'], 261);
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
        expect(activityData['activityPoints'], 100);
        expect(userData['totalPoints'], 100);
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
      expect(userData['totalPoints'], 300);
      expect(examAttempt['earnedPoints'], 0);
    });
  });
}

const _uid = 'uid-123';
const _categoryId = 'relations_violence_digital';
const _lessonId = 'relations_violence';
const _activityId = 'relations_violence_activity_01';
const _examId = 'relations_violence_final_exam';

Future<CompletedQuizAttemptPersistenceResult> _completeActivity(
  CategoryProgressRepository repository, {
  required String attemptId,
  required Set<String> correctQuestionIds,
}) {
  final questionIds = _ids(1, 10).toList();
  return repository.completeActivityAttempt(
    uid: _uid,
    categoryId: _categoryId,
    lessonId: _lessonId,
    activityId: _activityId,
    attemptId: attemptId,
    startedAt: DateTime.utc(2026, 9, 10),
    questionIds: questionIds,
    answers: _answers(correctQuestionIds),
    totalLessonPages: 4,
    totalActivities: 6,
  );
}

List<CategoryProgressAnswer> _answers(Set<String> correctQuestionIds) {
  return _ids(1, 10)
      .map((questionId) {
        return CategoryProgressAnswer(
          questionId: questionId,
          answer: correctQuestionIds.contains(questionId)
              ? 'correct'
              : 'incorrect',
          isCorrect: false,
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

Future<void> _seedUser(FakeFirebaseFirestore firestore, {int totalPoints = 0}) {
  return _userDocument(firestore).set({
    'email': 'persona@yomecuido.test',
    'role': 'user',
    'totalPoints': totalPoints,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
  });
}

Future<void> _seedQuestions(FakeFirebaseFirestore firestore) async {
  for (final questionId in _ids(1, 10)) {
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
              activityId: _activityId,
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
  FakeFirebaseFirestore firestore,
) async {
  final snapshot = await _activityDocument(firestore).get();
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

Future<Map<String, dynamic>> _userData(FakeFirebaseFirestore firestore) async {
  final snapshot = await _userDocument(firestore).get();
  return snapshot.data()!;
}

DocumentReference<Map<String, dynamic>> _userDocument(
  FakeFirebaseFirestore firestore,
) {
  return firestore.collection(UserProfileRepository.usersCollection).doc(_uid);
}

DocumentReference<Map<String, dynamic>> _activityDocument(
  FakeFirebaseFirestore firestore,
) {
  return _userDocument(firestore)
      .collection('categoryProgress')
      .doc(_categoryId)
      .collection('activities')
      .doc(_activityId);
}
