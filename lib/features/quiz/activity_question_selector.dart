import '../../data/models/learning_activity.dart';
import '../../data/models/quiz_question.dart';
import '../../data/repositories/content_repository.dart';

class ActivityQuestionSelector {
  const ActivityQuestionSelector({this.questionsPerActivity = 10});

  final int questionsPerActivity;

  Future<List<QuizQuestion>> selectQuestions({
    required ContentRepository contentRepository,
    required String categoryId,
    required LearningActivity activity,
  }) async {
    final questions = await contentRepository.loadQuizQuestions(categoryId);
    return selectFromBank(
      questions: questions,
      categoryId: categoryId,
      activity: activity,
    );
  }

  Map<String, int> countQuestionsByActivity({
    required List<QuizQuestion> questions,
    required String categoryId,
    required List<LearningActivity> activities,
  }) {
    return <String, int>{
      for (final activity in activities)
        activity.id: selectFromBank(
          questions: questions,
          categoryId: categoryId,
          activity: activity,
        ).length,
    };
  }

  List<QuizQuestion> selectFromBank({
    required List<QuizQuestion> questions,
    required String categoryId,
    required LearningActivity activity,
  }) {
    if (questionsPerActivity < 1) {
      throw const FormatException('Questions per activity must be positive.');
    }

    final activityIndex = activity.order - 1;
    if (activityIndex < 0) {
      throw const FormatException('Activity order must be positive.');
    }

    final startIndex = activityIndex * questionsPerActivity;
    final orderedQuestions = _uniqueCategoryQuestions(questions, categoryId)
      ..sort(_compareByQuestionNumber);
    if (startIndex >= orderedQuestions.length) {
      return const <QuizQuestion>[];
    }

    final endIndex = (startIndex + questionsPerActivity).clamp(
      0,
      orderedQuestions.length,
    );
    return List<QuizQuestion>.unmodifiable(
      orderedQuestions.sublist(startIndex, endIndex),
    );
  }

  List<QuizQuestion> _uniqueCategoryQuestions(
    List<QuizQuestion> questions,
    String categoryId,
  ) {
    final uniqueById = <String, QuizQuestion>{};
    for (final question in questions) {
      if (question.categoryId == categoryId) {
        uniqueById.putIfAbsent(question.id, () => question);
      }
    }
    return uniqueById.values.toList(growable: false);
  }

  int _compareByQuestionNumber(QuizQuestion a, QuizQuestion b) {
    final aNumber = _questionNumber(a.id);
    final bNumber = _questionNumber(b.id);
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    if (aNumber != null && bNumber == null) {
      return -1;
    }
    if (aNumber == null && bNumber != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

  int? _questionNumber(String questionId) {
    final match = RegExp(r'(?:^|_)q?(\d+)$').firstMatch(questionId);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }
}
