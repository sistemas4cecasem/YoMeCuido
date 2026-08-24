import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryProgressRecord', () {
    test('serializes stable status and progress fields without percentage', () {
      final now = DateTime.utc(2026, 8, 21, 20, 30);
      final record = CategoryProgressRecord(
        categoryId: 'relations_violence_digital',
        lessonId: 'relations_violence',
        status: CategoryProgressStatus.completed,
        viewedLessonPageIds: const <String>['what_is_digital_violence'],
        completedActivityIds: const <String>['activity_1'],
        correctAnswers: 1,
        totalLessonPages: 4,
        totalActivities: 12,
        attemptCount: 1,
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
        },
      );

      final data = record.toFirestore();

      expect(data['status'], 'completed');
      expect(data['completedActivityIds'], <String>['activity_1']);
      expect(data['latestAnswers'], contains('activity_1'));
      expect(data, isNot(contains('percentage')));
      expect(record.status.firestoreValue, 'completed');
    });

    test('deserializes latest answer entries from Firestore data', () {
      final now = Timestamp.fromDate(DateTime.utc(2026, 8, 21, 20, 30));
      final data = {
        'categoryId': 'relations_violence_digital',
        'lessonId': 'relations_violence',
        'status': 'inProgress',
        'viewedLessonPageIds': <String>[
          'what_is_digital_violence',
          'control_is_not_care',
        ],
        'completedActivityIds': <String>['activity_1'],
        'correctAnswers': 1,
        'totalLessonPages': 4,
        'totalActivities': 12,
        'attemptCount': 1,
        'startedAt': now,
        'lastActivityAt': now,
        'completedAt': null,
        'updatedAt': now,
        'latestAnswers': <String, dynamic>{
          'activity_1': <String, dynamic>{
            'answer': 'control_passwords_threaten_messages',
            'isCorrect': true,
            'answeredAt': now,
          },
        },
      };

      final record = CategoryProgressRecord.fromMap(data);

      expect(record.status, CategoryProgressStatus.inProgress);
      expect(record.viewedLessonPageIds, hasLength(2));
      expect(record.completedActivityIds, <String>['activity_1']);
      expect(record.latestAnswers['activity_1']?.isCorrect, isTrue);
      expect(record.completedAt, isNull);
    });
  });
}
