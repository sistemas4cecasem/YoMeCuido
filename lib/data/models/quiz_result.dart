class QuizResult {
  const QuizResult({
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.closingMessage,
  });

  factory QuizResult.fromScore({
    required int correctAnswers,
    required int totalQuestions,
  }) {
    if (totalQuestions <= 0) {
      throw ArgumentError('totalQuestions must be greater than zero.');
    }
    if (correctAnswers < 0 || correctAnswers > totalQuestions) {
      throw ArgumentError('correctAnswers is out of range.');
    }

    final percentage = ((correctAnswers / totalQuestions) * 100).round();

    return QuizResult(
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      percentage: percentage,
      closingMessage: _messageFor(correctAnswers),
    );
  }

  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final String closingMessage;

  QuizResultLevel get level {
    if (correctAnswers >= 10) {
      return QuizResultLevel.high;
    }
    if (correctAnswers >= 7) {
      return QuizResultLevel.medium;
    }

    return QuizResultLevel.low;
  }

  String get achievementLabel {
    return switch (level) {
      QuizResultLevel.high => '¡Bien hecho!',
      QuizResultLevel.medium => 'Buen avance',
      QuizResultLevel.low => 'Necesita refuerzo',
    };
  }

  String get headlineMessage {
    return switch (level) {
      QuizResultLevel.high => 'Sigue así, vas muy bien.',
      QuizResultLevel.medium => 'Vas avanzando, sigue practicando.',
      QuizResultLevel.low => 'Puedes repetir y reforzar con calma.',
    };
  }

  String get characterAssetKey {
    return switch (level) {
      QuizResultLevel.high => 'boyCompleted',
      QuizResultLevel.medium => 'girlProgress',
      QuizResultLevel.low => 'boyThinking',
    };
  }

  static String _messageFor(int correctAnswers) {
    if (correctAnswers >= 10) {
      return 'Muy bien. Reconoces varias señales de riesgo y acciones de protección.';
    }
    if (correctAnswers >= 7) {
      return 'Buen trabajo. Sigue practicando para fortalecer tus decisiones de autocuidado.';
    }

    return 'Has completado la lección. Puedes repetirla y revisar nuevamente las recomendaciones.';
  }
}

enum QuizResultLevel { high, medium, low }
