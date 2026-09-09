class ActivityAnswerScore {
  const ActivityAnswerScore({
    required this.isCorrect,
    required this.alreadyScored,
  });

  final bool isCorrect;
  final bool alreadyScored;
}

class ActivityScoringPolicy {
  const ActivityScoringPolicy();

  static const firstAttemptPoints = 10;
  static const secondAttemptPoints = 5;
  static const thirdAttemptPoints = 1;
  static const firstNonScoringAttempt = 4;

  int pointsForCorrectAnswer({required int attemptNumber}) {
    _validateAttemptNumber(attemptNumber);

    return switch (attemptNumber) {
      1 => firstAttemptPoints,
      2 => secondAttemptPoints,
      3 => thirdAttemptPoints,
      >= firstNonScoringAttempt => 0,
      _ => throw StateError('Unexpected attempt number "$attemptNumber".'),
    };
  }

  bool canAwardPoints({
    required int attemptNumber,
    required bool isCorrect,
    required bool alreadyScored,
  }) {
    return earnedPointsForAnswer(
          attemptNumber: attemptNumber,
          isCorrect: isCorrect,
          alreadyScored: alreadyScored,
        ) >
        0;
  }

  int earnedPointsForAnswer({
    required int attemptNumber,
    required bool isCorrect,
    required bool alreadyScored,
  }) {
    _validateAttemptNumber(attemptNumber);

    if (!isCorrect || alreadyScored) {
      return 0;
    }

    return pointsForCorrectAnswer(attemptNumber: attemptNumber);
  }

  int earnedPointsForAttempt({
    required int attemptNumber,
    required Iterable<ActivityAnswerScore> answers,
  }) {
    _validateAttemptNumber(attemptNumber);

    return answers.fold<int>(0, (total, answer) {
      return total +
          earnedPointsForAnswer(
            attemptNumber: attemptNumber,
            isCorrect: answer.isCorrect,
            alreadyScored: answer.alreadyScored,
          );
    });
  }

  void _validateAttemptNumber(int attemptNumber) {
    if (attemptNumber < 1) {
      throw ArgumentError.value(
        attemptNumber,
        'attemptNumber',
        'Must represent a finalized attempt starting at 1.',
      );
    }
  }
}
