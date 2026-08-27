import '../models/category.dart';
import '../models/final_exam.dart';
import '../models/learning_activity.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';
import 'educational_content_firestore_mapper.dart';

const _categoriesCollection = 'categories';
const _lessonPagesCollection = 'lessonPages';
const _activitiesCollection = 'activities';
const _questionsCollection = 'questions';
const _examConfigCollection = 'examConfig';
const _finalExamDocumentId = 'final';

class EducationalContentSeedBundle {
  const EducationalContentSeedBundle({
    required this.categories,
    required this.lessonPagesByCategory,
    required this.activitiesByCategory,
    required this.questionsByCategory,
    required this.examConfigsByCategory,
  });

  final List<Category> categories;
  final Map<String, List<LessonPage>> lessonPagesByCategory;
  final Map<String, List<LearningActivity>> activitiesByCategory;
  final Map<String, List<QuizQuestion>> questionsByCategory;
  final Map<String, FinalExamConfig> examConfigsByCategory;
}

class EducationalContentSeedDocument {
  const EducationalContentSeedDocument({
    required this.path,
    required this.data,
  });

  final String path;
  final Map<String, Object?> data;
}

class EducationalContentSeedPlan {
  const EducationalContentSeedPlan(this.documents);

  final List<EducationalContentSeedDocument> documents;

  int get categoryCount => _countByDepth(2);

  int get lessonPageCount => _countByCollection(_lessonPagesCollection);

  int get activityCount => _countByCollection(_activitiesCollection);

  int get questionCount => _countByCollection(_questionsCollection);

  int get examConfigCount => _countByCollection(_examConfigCollection);

  List<String> get paths {
    return documents.map((document) => document.path).toList(growable: false);
  }

  int _countByDepth(int segmentCount) {
    return documents
        .where((document) => document.path.split('/').length == segmentCount)
        .length;
  }

  int _countByCollection(String collectionId) {
    return documents.where((document) {
      final segments = document.path.split('/');
      return segments.length >= 2 &&
          segments[segments.length - 2] == collectionId;
    }).length;
  }
}

abstract final class EducationalContentSeedBuilder {
  static const categoriesCollection = _categoriesCollection;
  static const lessonPagesCollection = _lessonPagesCollection;
  static const activitiesCollection = _activitiesCollection;
  static const questionsCollection = _questionsCollection;
  static const examConfigCollection = _examConfigCollection;
  static const finalExamDocumentId = _finalExamDocumentId;

  static EducationalContentSeedPlan build(EducationalContentSeedBundle bundle) {
    validate(bundle);

    final documents = <EducationalContentSeedDocument>[];
    for (var index = 0; index < bundle.categories.length; index += 1) {
      final category = bundle.categories[index];
      documents.add(
        EducationalContentSeedDocument(
          path: '$categoriesCollection/${category.id}',
          data: EducationalContentFirestoreMapper.categoryToMap(
            category,
            order: index + 1,
          ),
        ),
      );

      final categoryId = category.id;
      for (final page in bundle.lessonPagesByCategory[categoryId] ?? const []) {
        documents.add(
          EducationalContentSeedDocument(
            path:
                '$categoriesCollection/$categoryId/'
                '$lessonPagesCollection/${page.id}',
            data: EducationalContentFirestoreMapper.lessonPageToMap(page),
          ),
        );
      }

      for (final activity
          in bundle.activitiesByCategory[categoryId] ?? const []) {
        documents.add(
          EducationalContentSeedDocument(
            path:
                '$categoriesCollection/$categoryId/'
                '$activitiesCollection/${activity.id}',
            data: EducationalContentFirestoreMapper.activityToMap(activity),
          ),
        );
      }

      for (final question
          in bundle.questionsByCategory[categoryId] ?? const []) {
        documents.add(
          EducationalContentSeedDocument(
            path:
                '$categoriesCollection/$categoryId/'
                '$questionsCollection/${question.id}',
            data: EducationalContentFirestoreMapper.questionToMap(question),
          ),
        );
      }

      final examConfig = bundle.examConfigsByCategory[categoryId];
      if (examConfig != null) {
        documents.add(
          EducationalContentSeedDocument(
            path:
                '$categoriesCollection/$categoryId/'
                '$examConfigCollection/$finalExamDocumentId',
            data: EducationalContentFirestoreMapper.examConfigToMap(examConfig),
          ),
        );
      }
    }

    _ensureUniquePaths(documents.map((document) => document.path));
    return EducationalContentSeedPlan(documents);
  }

  static void validate(EducationalContentSeedBundle bundle) {
    _ensureNotEmpty(bundle.categories, 'categories');
    _ensureUniqueIds(
      bundle.categories.map((category) => category.id),
      'category',
    );

    final categoryIds = bundle.categories
        .map((category) => category.id)
        .toSet();
    final activityIdsByCategory = <String, Set<String>>{};

    for (final category in bundle.categories) {
      _ensureId(category.id, 'category.id');
      final activities =
          bundle.activitiesByCategory[category.id] ??
          const <LearningActivity>[];
      _ensureUniqueIds(activities.map((activity) => activity.id), 'activity');
      activityIdsByCategory[category.id] = activities
          .map((activity) => activity.id)
          .toSet();
    }

    for (final entry in bundle.lessonPagesByCategory.entries) {
      _ensureKnownCategory(entry.key, categoryIds);
      _ensureUniqueIds(entry.value.map((page) => page.id), 'lesson page');
      for (final page in entry.value) {
        _ensureId(page.id, 'lessonPage.id');
        if (page.order < 1) {
          throw const EducationalContentSeedException(
            'Lesson page order must be positive.',
          );
        }
      }
    }

    for (final entry in bundle.activitiesByCategory.entries) {
      _ensureKnownCategory(entry.key, categoryIds);
      for (final activity in entry.value) {
        _ensureId(activity.id, 'activity.id');
        if (activity.categoryId != entry.key) {
          throw const EducationalContentSeedException(
            'Activity categoryId must match parent category.',
          );
        }
        if (activity.order < 1) {
          throw const EducationalContentSeedException(
            'Activity order must be positive.',
          );
        }
      }
    }

    for (final entry in bundle.questionsByCategory.entries) {
      _ensureKnownCategory(entry.key, categoryIds);
      _ensureUniqueIds(entry.value.map((question) => question.id), 'question');
      for (final question in entry.value) {
        _validateQuestion(question, entry.key, activityIdsByCategory);
      }
    }

    for (final entry in bundle.examConfigsByCategory.entries) {
      _ensureKnownCategory(entry.key, categoryIds);
      _validateExamConfig(entry.value, entry.key);
    }
  }

  static void _validateQuestion(
    QuizQuestion question,
    String categoryId,
    Map<String, Set<String>> activityIdsByCategory,
  ) {
    _ensureId(question.id, 'question.id');
    if (question.categoryId != categoryId) {
      throw const EducationalContentSeedException(
        'Question categoryId must match parent category.',
      );
    }
    if (!(activityIdsByCategory[categoryId] ?? const <String>{}).contains(
      question.activityId,
    )) {
      throw const EducationalContentSeedException(
        'Question activityId must reference an existing activity.',
      );
    }
    _ensureUniqueIds(question.options.map((option) => option.id), 'option');
    for (final option in question.options) {
      _ensureId(option.id, 'option.id');
      if (option.text.trim().isEmpty) {
        throw const EducationalContentSeedException(
          'Option text cannot be empty.',
        );
      }
    }
    if (question.type == QuestionType.fillBlank) {
      if (question.options.isNotEmpty) {
        throw const EducationalContentSeedException(
          'Fill blank questions cannot include options.',
        );
      }
      if (!question.acceptedAnswers.contains(question.correctAnswer)) {
        throw const EducationalContentSeedException(
          'Fill blank acceptedAnswers must include correctAnswer.',
        );
      }
      return;
    }

    if (!question.options.any(
      (option) => option.id == question.correctAnswer,
    )) {
      throw const EducationalContentSeedException(
        'Question correctAnswer must match an option id.',
      );
    }
  }

  static void _validateExamConfig(FinalExamConfig exam, String categoryId) {
    _ensureId(exam.id, 'exam.id');
    if (exam.categoryId != categoryId) {
      throw const EducationalContentSeedException(
        'Exam config categoryId must match parent category.',
      );
    }
    if (exam.questionCount < 1) {
      throw const EducationalContentSeedException(
        'Exam questionCount must be positive.',
      );
    }
    if (exam.minimumQuestionsPerActivity < 0) {
      throw const EducationalContentSeedException(
        'Exam minimumQuestionsPerActivity cannot be negative.',
      );
    }
    final targetQuestionCount = exam.targetDifficultyCounts.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    if (targetQuestionCount != exam.questionCount) {
      throw const EducationalContentSeedException(
        'Exam target difficulty counts must match questionCount.',
      );
    }
  }

  static void _ensureKnownCategory(String categoryId, Set<String> categoryIds) {
    if (!categoryIds.contains(categoryId)) {
      throw const EducationalContentSeedException(
        'Content references an unknown categoryId.',
      );
    }
  }

  static void _ensureNotEmpty(Iterable<Object?> values, String name) {
    if (values.isEmpty) {
      throw EducationalContentSeedException('$name cannot be empty.');
    }
  }

  static void _ensureId(String id, String name) {
    if (id.trim().isEmpty) {
      throw EducationalContentSeedException('$name cannot be empty.');
    }
  }

  static void _ensureUniqueIds(Iterable<String> ids, String label) {
    final seen = <String>{};
    for (final id in ids) {
      _ensureId(id, '$label id');
      if (!seen.add(id)) {
        throw EducationalContentSeedException('Duplicate $label id "$id".');
      }
    }
  }

  static void _ensureUniquePaths(Iterable<String> paths) {
    final seen = <String>{};
    for (final path in paths) {
      if (!seen.add(path)) {
        throw EducationalContentSeedException('Duplicate seed path "$path".');
      }
    }
  }
}

class EducationalContentSeedException implements Exception {
  const EducationalContentSeedException(this.message);

  final String message;

  @override
  String toString() => message;
}
