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
