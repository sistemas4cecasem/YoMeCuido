import 'dart:math' as math;

import '../../data/models/final_exam.dart';
import '../../data/models/quiz_question.dart';
import '../../data/repositories/content_repository.dart';

class InsufficientExamQuestionsException implements Exception {
  const InsufficientExamQuestionsException({
    required this.requiredQuestions,
    required this.availableQuestions,
  });

  final int requiredQuestions;
  final int availableQuestions;

  @override
  String toString() {
    return 'InsufficientExamQuestionsException($availableQuestions/'
        '$requiredQuestions)';
  }
}

class ExamQuestionSelector {
  const ExamQuestionSelector({math.Random? random}) : _random = random;

  final math.Random? _random;

  Future<List<QuizQuestion>> selectQuestions({
    required ContentRepository contentRepository,
    required FinalExamConfig exam,
  }) async {
    final questions = await contentRepository.loadQuizQuestions(
      exam.categoryId,
    );
    final categoryQuestions = questions
        .where((question) => question.categoryId == exam.categoryId)
        .toList(growable: false);

    if (categoryQuestions.length < exam.questionCount) {
      throw InsufficientExamQuestionsException(
        requiredQuestions: exam.questionCount,
        availableQuestions: categoryQuestions.length,
      );
    }

    final selected = categoryQuestions.toList(growable: false)
      ..shuffle(_random);
    return List<QuizQuestion>.unmodifiable(selected.take(exam.questionCount));
  }
}
