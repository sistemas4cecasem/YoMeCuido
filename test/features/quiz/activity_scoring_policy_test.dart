import 'package:demo_yomecuido/features/quiz/activity_scoring_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityScoringPolicy', () {
    const policy = ActivityScoringPolicy();

    test('awards 10 points for a new correct answer on attempt 1', () {
      expect(
        policy.earnedPointsForAnswer(
          attemptNumber: 1,
          isCorrect: true,
          alreadyScored: false,
        ),
        10,
      );
    });

    test('awards 5 points for a new correct answer on attempt 2', () {
      expect(
        policy.earnedPointsForAnswer(
          attemptNumber: 2,
          isCorrect: true,
          alreadyScored: false,
        ),
        5,
      );
    });

    test('awards 1 point for a new correct answer on attempt 3', () {
      expect(
        policy.earnedPointsForAnswer(
          attemptNumber: 3,
          isCorrect: true,
          alreadyScored: false,
        ),
        1,
      );
    });

    test('awards no points for a new correct answer on attempt 4', () {
      expect(
        policy.earnedPointsForAnswer(
          attemptNumber: 4,
          isCorrect: true,
          alreadyScored: false,
        ),
        0,
      );
    });

    test('awards no points for a very high attempt number', () {
      expect(
        policy.earnedPointsForAnswer(
          attemptNumber: 20,
          isCorrect: true,
          alreadyScored: false,
        ),
        0,
      );
    });

    test('awards no points for incorrect answers on scoring attempts', () {
      for (final attemptNumber in <int>[1, 2, 3]) {
        expect(
          policy.earnedPointsForAnswer(
            attemptNumber: attemptNumber,
            isCorrect: false,
            alreadyScored: false,
          ),
          0,
        );
      }
    });

    test('awards no points when the question already scored', () {
      for (final attemptNumber in <int>[1, 2, 3]) {
        expect(
          policy.earnedPointsForAnswer(
            attemptNumber: attemptNumber,
            isCorrect: true,
            alreadyScored: true,
          ),
          0,
        );
      }
    });

    test('reports whether a question can receive points', () {
      expect(
        policy.canAwardPoints(
          attemptNumber: 1,
          isCorrect: true,
          alreadyScored: false,
        ),
        isTrue,
      );
      expect(
        policy.canAwardPoints(
          attemptNumber: 1,
          isCorrect: false,
          alreadyScored: false,
        ),
        isFalse,
      );
      expect(
        policy.canAwardPoints(
          attemptNumber: 1,
          isCorrect: true,
          alreadyScored: true,
        ),
        isFalse,
      );
    });

    test('rejects invalid attempt numbers', () {
      expect(
        () => policy.earnedPointsForAnswer(
          attemptNumber: 0,
          isCorrect: true,
          alreadyScored: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => policy.earnedPointsForAnswer(
          attemptNumber: -1,
          isCorrect: true,
          alreadyScored: false,
        ),
        throwsArgumentError,
      );
    });

    test('calculates the complete lifetime scoring scenario', () {
      final firstAttemptPoints = policy.earnedPointsForAttempt(
        attemptNumber: 1,
        answers: <ActivityAnswerScore>[
          for (var index = 0; index < 5; index += 1)
            const ActivityAnswerScore(isCorrect: true, alreadyScored: false),
          for (var index = 0; index < 5; index += 1)
            const ActivityAnswerScore(isCorrect: false, alreadyScored: false),
        ],
      );
      final secondAttemptPoints = policy.earnedPointsForAttempt(
        attemptNumber: 2,
        answers: const <ActivityAnswerScore>[
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: false),
          ActivityAnswerScore(isCorrect: true, alreadyScored: false),
          ActivityAnswerScore(isCorrect: false, alreadyScored: false),
          ActivityAnswerScore(isCorrect: false, alreadyScored: false),
          ActivityAnswerScore(isCorrect: false, alreadyScored: false),
        ],
      );
      final thirdAttemptPoints = policy.earnedPointsForAttempt(
        attemptNumber: 3,
        answers: const <ActivityAnswerScore>[
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: true),
          ActivityAnswerScore(isCorrect: true, alreadyScored: false),
          ActivityAnswerScore(isCorrect: false, alreadyScored: false),
          ActivityAnswerScore(isCorrect: false, alreadyScored: false),
        ],
      );
      final fourthAttemptPoints = policy.earnedPointsForAttempt(
        attemptNumber: 4,
        answers: const <ActivityAnswerScore>[
          ActivityAnswerScore(isCorrect: true, alreadyScored: false),
          ActivityAnswerScore(isCorrect: true, alreadyScored: false),
        ],
      );

      expect(firstAttemptPoints, 50);
      expect(secondAttemptPoints, 10);
      expect(thirdAttemptPoints, 1);
      expect(fourthAttemptPoints, 0);
      expect(
        firstAttemptPoints +
            secondAttemptPoints +
            thirdAttemptPoints +
            fourthAttemptPoints,
        61,
      );
    });
  });
}
