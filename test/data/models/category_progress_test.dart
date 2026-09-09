import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuestionScoreRecord', () {
    test('represents awarded and pending question scores', () {
      const firstAttemptScore = QuestionScoreRecord(
        questionId: 'question_01',
        pointsAwarded: 10,
        awardedAttempt: 1,
      );
      const secondAttemptScore = QuestionScoreRecord(
        questionId: 'question_02',
        pointsAwarded: 5,
        awardedAttempt: 2,
      );
      const thirdAttemptScore = QuestionScoreRecord(
        questionId: 'question_03',
        pointsAwarded: 1,
        awardedAttempt: 3,
      );
      const pendingScore = QuestionScoreRecord.notAwarded(
        questionId: 'question_04',
      );

      expect(firstAttemptScore.hasAwardedPoints, isTrue);
      expect(secondAttemptScore.pointsAwarded, 5);
      expect(thirdAttemptScore.awardedAttempt, 3);
      expect(pendingScore.pointsAwarded, 0);
      expect(pendingScore.awardedAttempt, isNull);
      expect(pendingScore.hasAwardedPoints, isFalse);
    });

    test('serializes and deserializes question score state', () {
      const score = QuestionScoreRecord(
        questionId: 'question_01',
        pointsAwarded: 10,
        awardedAttempt: 1,
      );

      final rebuilt = QuestionScoreRecord.fromMap(
        questionId: 'question_01',
        data: score.toFirestore(),
      );

      expect(rebuilt.questionId, score.questionId);
      expect(rebuilt.pointsAwarded, score.pointsAwarded);
      expect(rebuilt.awardedAttempt, score.awardedAttempt);
    });

    test('rejects invalid question score states', () {
      expect(
        () => QuestionScoreRecord.fromMap(
          questionId: 'question_01',
          data: <String, dynamic>{'pointsAwarded': 10, 'awardedAttempt': 2},
        ),
        throwsFormatException,
      );
      expect(
        () => QuestionScoreRecord.fromMap(
          questionId: 'question_01',
          data: <String, dynamic>{'pointsAwarded': -1, 'awardedAttempt': null},
        ),
        throwsFormatException,
      );
    });
  });

  group('CategoryProgressRecord', () {
    test(
      'serializes category progress without answers or attempt counters',
      () {
        final now = DateTime.utc(2026, 8, 21, 20, 30);
        final record = CategoryProgressRecord(
          categoryId: 'relations_violence_digital',
          lessonId: 'relations_violence',
          status: CategoryProgressStatus.completed,
          viewedLessonPageIds: const <String>['what_is_digital_violence'],
          completedActivityIds: const <String>[
            'relations_violence_activity_01',
          ],
          totalLessonPages: 4,
          totalActivities: 6,
          startedAt: now,
          lastActivityAt: now,
          completedAt: now,
          updatedAt: now,
          activities: const <String, ActivityProgressRecord>{},
          exams: const <String, ExamProgressRecord>{},
        );

        final data = record.toFirestore();

        expect(data['status'], 'completed');
        expect(data['completedActivityIds'], <String>[
          'relations_violence_activity_01',
        ]);
        expect(data, isNot(contains('latestAnswers')));
        expect(data, isNot(contains('attemptCount')));
        expect(data, isNot(contains('correctAnswers')));
        expect(record.status.firestoreValue, 'completed');
      },
    );

    test('deserializes category progress with activity records', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final data = {
        'categoryId': 'relations_violence_digital',
        'lessonId': 'relations_violence',
        'status': 'inProgress',
        'viewedLessonPageIds': <String>[
          'what_is_digital_violence',
          'control_is_not_care',
        ],
        'completedActivityIds': <String>['relations_violence_activity_01'],
        'totalLessonPages': 4,
        'totalActivities': 6,
        'startedAt': now,
        'lastActivityAt': now,
        'completedAt': null,
        'updatedAt': now,
      };
      final activity = ActivityProgressRecord(
        activityId: 'relations_violence_activity_01',
        status: ActivityProgressStatus.completed,
        attemptCount: 2,
        bestCorrectAnswers: 4,
        bestTotalQuestions: 5,
        bestPercentage: 80,
        lastAttemptAt: now.toDate(),
        completedAt: now.toDate(),
        updatedAt: now.toDate(),
      );
      final exam = ExamProgressRecord(
        examId: 'relations_violence_final_exam',
        status: ActivityProgressStatus.completed,
        attemptCount: 1,
        bestCorrectAnswers: 12,
        bestTotalQuestions: 15,
        bestPercentage: 80,
        lastAttemptAt: now.toDate(),
        completedAt: now.toDate(),
        updatedAt: now.toDate(),
      );

      final record = CategoryProgressRecord.fromMap(
        data,
        activities: <String, ActivityProgressRecord>{
          activity.activityId: activity,
        },
        exams: <String, ExamProgressRecord>{exam.examId: exam},
      );

      expect(record.status, CategoryProgressStatus.inProgress);
      expect(record.viewedLessonPageIds, hasLength(2));
      expect(record.completedActivityIds, <String>[
        'relations_violence_activity_01',
      ]);
      expect(
        record.activities['relations_violence_activity_01']?.bestPercentage,
        80,
      );
      expect(record.exams['relations_violence_final_exam']?.attemptCount, 1);
      expect(record.completedAt, isNull);
    });
  });

  group('ActivityProgressRecord', () {
    test('serializes best score fields for a real activity', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final record = ActivityProgressRecord(
        activityId: 'relations_violence_activity_01',
        status: ActivityProgressStatus.completed,
        attemptCount: 3,
        activityPoints: 61,
        questionScores: const <String, QuestionScoreRecord>{
          'question_01': QuestionScoreRecord(
            questionId: 'question_01',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'question_06': QuestionScoreRecord(
            questionId: 'question_06',
            pointsAwarded: 5,
            awardedAttempt: 2,
          ),
          'question_08': QuestionScoreRecord(
            questionId: 'question_08',
            pointsAwarded: 1,
            awardedAttempt: 3,
          ),
          'question_09': QuestionScoreRecord.notAwarded(
            questionId: 'question_09',
          ),
        },
        bestCorrectAnswers: 4,
        bestTotalQuestions: 5,
        bestPercentage: 80,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      );

      final data = record.toFirestore();

      expect(data['activityId'], 'relations_violence_activity_01');
      expect(data['status'], 'completed');
      expect(data['attemptCount'], 3);
      expect(data['activityPoints'], 61);
      expect(data['questionScores'], contains('question_01'));
      expect(data['bestPercentage'], 80);
    });

    test('deserializes old activity progress with scoring defaults', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));

      final record = ActivityProgressRecord.fromMap(<String, dynamic>{
        'activityId': 'relations_violence_activity_01',
        'status': 'completed',
        'attemptCount': 3,
        'bestCorrectAnswers': 4,
        'bestTotalQuestions': 5,
        'bestPercentage': 80,
        'lastAttemptAt': now,
        'completedAt': now,
        'updatedAt': now,
      });

      expect(record.activityPoints, 0);
      expect(record.questionScores, isEmpty);
    });

    test('round-trips representative 61 point activity state', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final record = ActivityProgressRecord(
        activityId: 'relations_violence_activity_01',
        status: ActivityProgressStatus.completed,
        attemptCount: 3,
        activityPoints: 61,
        questionScores: const <String, QuestionScoreRecord>{
          'q01': QuestionScoreRecord(
            questionId: 'q01',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'q02': QuestionScoreRecord(
            questionId: 'q02',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'q03': QuestionScoreRecord(
            questionId: 'q03',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'q04': QuestionScoreRecord(
            questionId: 'q04',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'q05': QuestionScoreRecord(
            questionId: 'q05',
            pointsAwarded: 10,
            awardedAttempt: 1,
          ),
          'q06': QuestionScoreRecord(
            questionId: 'q06',
            pointsAwarded: 5,
            awardedAttempt: 2,
          ),
          'q07': QuestionScoreRecord(
            questionId: 'q07',
            pointsAwarded: 5,
            awardedAttempt: 2,
          ),
          'q08': QuestionScoreRecord(
            questionId: 'q08',
            pointsAwarded: 1,
            awardedAttempt: 3,
          ),
          'q09': QuestionScoreRecord.notAwarded(questionId: 'q09'),
          'q10': QuestionScoreRecord.notAwarded(questionId: 'q10'),
        },
        bestCorrectAnswers: 8,
        bestTotalQuestions: 10,
        bestPercentage: 80,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      );

      final rebuilt = ActivityProgressRecord.fromMap(record.toFirestore());

      expect(rebuilt.attemptCount, 3);
      expect(rebuilt.activityPoints, 61);
      expect(rebuilt.questionScores, hasLength(10));
      expect(rebuilt.questionScores['q08']?.pointsAwarded, 1);
      expect(rebuilt.questionScores['q09']?.awardedAttempt, isNull);
      expect(rebuilt.bestPercentage, 80);
    });

    test('rejects negative activity points', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));

      expect(
        () => ActivityProgressRecord.fromMap(<String, dynamic>{
          'activityId': 'relations_violence_activity_01',
          'status': 'completed',
          'attemptCount': 3,
          'activityPoints': -1,
          'bestCorrectAnswers': 4,
          'bestTotalQuestions': 5,
          'bestPercentage': 80,
          'lastAttemptAt': now,
          'completedAt': now,
          'updatedAt': now,
        }),
        throwsFormatException,
      );
    });
  });

  group('ExamProgressRecord', () {
    test('serializes best score fields for the final exam', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final record = ExamProgressRecord(
        examId: 'relations_violence_final_exam',
        status: ActivityProgressStatus.completed,
        attemptCount: 2,
        bestCorrectAnswers: 14,
        bestTotalQuestions: 15,
        bestPercentage: 93,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      );

      final data = record.toFirestore();

      expect(data['examId'], 'relations_violence_final_exam');
      expect(data['status'], 'completed');
      expect(data['attemptCount'], 2);
      expect(data['bestPercentage'], 93);
    });
  });

  group('QuizAttempt', () {
    test('serializes attempt identity, question order and answers', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final attempt = QuizAttempt(
        id: 'attempt_abc',
        attemptNumber: 2,
        type: QuizAttemptType.activity,
        categoryId: 'relations_violence_digital',
        activityId: 'relations_violence_activity_01',
        examId: null,
        questionIds: const <String>['question_07', 'question_02'],
        answers: <CategoryProgressAnswer>[
          CategoryProgressAnswer(
            questionId: 'question_07',
            answer: 'option_safe',
            isCorrect: true,
            pointsEarned: 5,
            answeredAt: now,
          ),
        ],
        correctAnswers: 1,
        totalQuestions: 2,
        percentage: 50,
        earnedPoints: 5,
        startedAt: now,
        completedAt: now,
      );

      final data = attempt.toFirestore();

      expect(data['attemptNumber'], 2);
      expect(data['type'], 'activity');
      expect(data['activityId'], 'relations_violence_activity_01');
      expect(data['examId'], isNull);
      expect(data['questionIds'], <String>['question_07', 'question_02']);
      expect(data['answers'], contains('question_07'));
      expect(
        data['answers'],
        isNot(contains('relations_violence_activity_01')),
      );
      expect(data['answers']['question_07']['pointsEarned'], 5);
      expect(data['percentage'], 50);
      expect(data['earnedPoints'], 5);
    });

    test('deserializes attempt scoring fields and answers by question id', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final attempt = QuizAttempt.fromMap(
        id: 'attempt_abc',
        data: <String, dynamic>{
          'attemptNumber': 2,
          'type': 'activity',
          'categoryId': 'relations_violence_digital',
          'activityId': 'relations_violence_activity_01',
          'examId': null,
          'questionIds': <String>['question_01'],
          'answers': <String, dynamic>{
            'question_01': <String, dynamic>{
              'questionId': 'question_01',
              'answer': 'option_safe',
              'isCorrect': true,
              'pointsEarned': 5,
              'answeredAt': now,
            },
          },
          'correctAnswers': 1,
          'totalQuestions': 1,
          'percentage': 100,
          'earnedPoints': 5,
          'startedAt': now,
          'completedAt': now,
        },
      );

      expect(attempt.id, 'attempt_abc');
      expect(attempt.attemptNumber, 2);
      expect(attempt.type, QuizAttemptType.activity);
      expect(attempt.activityId, 'relations_violence_activity_01');
      expect(attempt.examId, isNull);
      expect(attempt.answers.single.questionId, 'question_01');
      expect(attempt.answers.single.answer, 'option_safe');
      expect(attempt.answers.single.isCorrect, isTrue);
      expect(attempt.answers.single.pointsEarned, 5);
      expect(attempt.percentage, 100);
      expect(attempt.earnedPoints, 5);
    });

    test('deserializes old attempt documents with scoring defaults', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final attempt = QuizAttempt.fromMap(
        id: 'attempt_abc',
        data: <String, dynamic>{
          'type': 'activity',
          'categoryId': 'relations_violence_digital',
          'activityId': 'relations_violence_activity_01',
          'examId': null,
          'questionIds': <String>['question_01'],
          'answers': <String, dynamic>{
            'question_01': <String, dynamic>{
              'questionId': 'question_01',
              'answer': 'option_safe',
              'isCorrect': true,
              'answeredAt': now,
            },
          },
          'correctAnswers': 1,
          'totalQuestions': 1,
          'percentage': 100,
          'startedAt': now,
          'completedAt': now,
        },
      );

      expect(attempt.attemptNumber, 1);
      expect(attempt.earnedPoints, 0);
      expect(attempt.answers.single.pointsEarned, 0);
    });

    test('serializes an exam attempt without activity id', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final attempt = QuizAttempt(
        id: 'attempt_exam',
        attemptNumber: 1,
        type: QuizAttemptType.exam,
        categoryId: 'relations_violence_digital',
        activityId: null,
        examId: 'relations_violence_final_exam',
        questionIds: const <String>['question_01', 'question_02'],
        answers: const <CategoryProgressAnswer>[],
        correctAnswers: 0,
        totalQuestions: 2,
        percentage: 0,
        earnedPoints: 20,
        startedAt: now,
        completedAt: null,
      );

      final data = attempt.toFirestore();

      expect(data['type'], 'exam');
      expect(data['activityId'], isNull);
      expect(data['examId'], 'relations_violence_final_exam');
      expect(data['questionIds'], <String>['question_01', 'question_02']);
      expect(data['earnedPoints'], 0);
    });

    test('rejects invalid attempt number and negative earned points', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final baseData = <String, dynamic>{
        'type': 'activity',
        'categoryId': 'relations_violence_digital',
        'activityId': 'relations_violence_activity_01',
        'examId': null,
        'questionIds': <String>['question_01'],
        'answers': <String, dynamic>{},
        'correctAnswers': 0,
        'totalQuestions': 1,
        'percentage': 0,
        'startedAt': now,
        'completedAt': now,
      };

      expect(
        () => QuizAttempt.fromMap(
          id: 'attempt_abc',
          data: <String, dynamic>{...baseData, 'attemptNumber': 0},
        ),
        throwsFormatException,
      );
      expect(
        () => QuizAttempt.fromMap(
          id: 'attempt_abc',
          data: <String, dynamic>{...baseData, 'earnedPoints': -10},
        ),
        throwsFormatException,
      );
    });
  });
}
