import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/learning_activity.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';
import 'content_repository.dart';

class LocalContentRepository implements ContentRepository {
  LocalContentRepository({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const relationsViolenceCategoryId = 'relations_violence_digital';
  static const _categoriesPath = 'assets/data/categories.json';
  static const _lessonPath = 'assets/data/relations_violence_lesson.json';
  static const _activitiesPath =
      'assets/data/relations_violence_activities.json';
  static const _questionsPath = 'assets/data/relations_violence_questions.json';

  final AssetBundle _assetBundle;

  @override
  Future<List<Category>> loadCategories() {
    return _loadList(
      assetPath: _categoriesPath,
      listKey: 'categories',
      parser: Category.fromJson,
    );
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) {
    _validateSupportedCategory(categoryId);

    return _loadList(
      assetPath: _lessonPath,
      listKey: 'lessonPages',
      parser: LessonPage.fromJson,
    );
  }

  @override
  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    _validateSupportedCategory(categoryId);

    final activities = await _loadList(
      assetPath: _activitiesPath,
      listKey: 'activities',
      parser: LearningActivity.fromJson,
    );
    final categoryActivities = activities
        .where((activity) => activity.categoryId == categoryId)
        .toList(growable: false);

    return categoryActivities..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    _validateSupportedCategory(categoryId);

    final questions = await _loadList(
      assetPath: _questionsPath,
      listKey: 'questions',
      parser: QuizQuestion.fromJson,
    );
    return questions
        .where((question) {
          return question.categoryId == categoryId &&
              (activityId == null || question.activityId == activityId);
        })
        .toList(growable: false);
  }

  Future<List<T>> _loadList<T>({
    required String assetPath,
    required String listKey,
    required T Function(Map<String, Object?> json) parser,
  }) async {
    try {
      final source = await _assetBundle.loadString(assetPath);
      final decoded = jsonDecode(source);

      if (decoded is! Map<String, Object?>) {
        throw const FormatException('JSON root must be an object.');
      }

      final list = decoded[listKey];
      if (list is! List<Object?>) {
        throw FormatException('Missing or invalid "$listKey" list.');
      }

      return list
          .map((item) {
            if (item is Map<String, Object?>) {
              return parser(item);
            }

            throw FormatException('Invalid item in "$listKey" list.');
          })
          .toList(growable: false);
    } on ContentLoadException {
      rethrow;
    } catch (_) {
      throw const ContentLoadException();
    }
  }

  void _validateSupportedCategory(String categoryId) {
    if (categoryId != relationsViolenceCategoryId) {
      throw const ContentLoadException();
    }
  }
}
