import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/pending_quiz_attempt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reserved identity and correctness survive a local JSON round trip', () {
    final now = DateTime.utc(2026, 9, 25);
    final pending = PendingQuizAttempt(
      uid: 'uid-a',
      attemptId: 'stable-attempt',
      attemptNumber: 2,
      pointValue: 5,
      type: QuizAttemptType.activity,
      categoryId: 'category-a',
      lessonId: 'lesson-a',
      activityId: 'activity-a',
      examId: null,
      questionIds: [for (var index = 1; index <= 10; index++) 'q$index'],
      answers: [
        CategoryProgressAnswer(
          questionId: 'q1',
          answer: 'correct',
          isCorrect: true,
          answeredAt: now,
        ),
      ],
      correctQuestionIds: const ['q1'],
      correctAnswers: 1,
      totalQuestions: 10,
      percentage: 10,
      totalActivities: 6,
      startedAt: now,
      completedAt: now,
    );

    final restored = PendingQuizAttempt.fromJson(pending.toJson());
    expect(restored.uid, 'uid-a');
    expect(restored.attemptId, 'stable-attempt');
    expect(restored.attemptNumber, 2);
    expect(restored.pointValue, 5);
    expect(restored.correctQuestionIds, ['q1']);
    expect(restored.answers.single.answer, 'correct');
    expect(restored.completedAt, now);
  });
}
