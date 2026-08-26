import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

      final record = CategoryProgressRecord.fromMap(
        data,
        activities: <String, ActivityProgressRecord>{
          activity.activityId: activity,
        },
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
      expect(data['bestPercentage'], 80);
    });
  });

  group('QuizAttempt', () {
    test('serializes attempt identity, question order and answers', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final attempt = QuizAttempt(
        id: 'attempt_abc',
        type: QuizAttemptType.activity,
        categoryId: 'relations_violence_digital',
        activityId: 'relations_violence_activity_01',
        questionIds: const <String>['question_07', 'question_02'],
        answers: <CategoryProgressAnswer>[
          CategoryProgressAnswer(
            questionId: 'question_07',
            answer: 'option_safe',
            isCorrect: true,
            answeredAt: now,
          ),
        ],
        correctAnswers: 1,
        totalQuestions: 2,
        percentage: 50,
        startedAt: now,
        completedAt: now,
      );

      final data = attempt.toFirestore();

      expect(data['type'], 'activity');
      expect(data['activityId'], 'relations_violence_activity_01');
      expect(data['questionIds'], <String>['question_07', 'question_02']);
      expect(data['answers'], contains('question_07'));
      expect(
        data['answers'],
        isNot(contains('relations_violence_activity_01')),
      );
      expect(data['percentage'], 50);
    });

    test('deserializes answers by question id', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final attempt = QuizAttempt.fromMap(
        id: 'attempt_abc',
        data: <String, dynamic>{
          'type': 'activity',
          'categoryId': 'relations_violence_digital',
          'activityId': 'relations_violence_activity_01',
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

      expect(attempt.id, 'attempt_abc');
      expect(attempt.type, QuizAttemptType.activity);
      expect(attempt.answers.single.questionId, 'question_01');
      expect(attempt.answers.single.answer, 'option_safe');
      expect(attempt.percentage, 100);
    });
  });
}
