import '../models/category.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';

abstract class ContentRepository {
  Future<List<Category>> loadCategories();

  Future<List<LessonPage>> loadLessonPages(String categoryId);

  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId);
}

class ContentLoadException implements Exception {
  const ContentLoadException([
    this.message =
        'No pudimos cargar el contenido de la demo. Intenta nuevamente.',
  ]);

  final String message;

  @override
  String toString() => message;
}
