import '../models/category.dart';
import '../models/final_exam.dart';
import '../models/learning_activity.dart';
import '../models/lesson_page.dart';
import '../models/quiz_question.dart';

abstract final class EducationalContentFirestoreMapper {
  static Map<String, Object?> categoryToMap(
    Category category, {
    int order = 1,
  }) {
    return <String, Object?>{
      'id': category.id,
      'title': category.title,
      'description': category.description,
      'iconName': category.iconName,
      'status': _categoryStatusToString(category.status),
      'isEnabled': category.isEnabled,
      'order': order,
      'indicators': category.indicators,
      'objectives': category.objectives,
      if (category.warning != null) 'warning': category.warning,
      if (category.lessonId != null) 'lessonId': category.lessonId,
    };
  }

  static Category categoryFromMap(
    Map<String, Object?> data, {
    required String documentId,
  }) {
    final category = Category.fromJson(<String, Object?>{
      ...data,
      'id': _readStableId(data, documentId),
    });
    if (category.id != documentId) {
      throw const FormatException('Category id must match document id.');
    }
    return category;
  }

  static Map<String, Object?> lessonPageToMap(LessonPage page) {
    return <String, Object?>{
      'id': page.id,
      'order': page.order,
      'title': page.title,
      'body': page.body,
    };
  }

  static LessonPage lessonPageFromMap(
    Map<String, Object?> data, {
    required String documentId,
  }) {
    final page = LessonPage.fromJson(<String, Object?>{
      ...data,
      'id': _readStableId(data, documentId),
    });
    if (page.id != documentId) {
      throw const FormatException('Lesson page id must match document id.');
    }
    return page;
  }

  static Map<String, Object?> activityToMap(LearningActivity activity) {
    return <String, Object?>{
      'id': activity.id,
      'categoryId': activity.categoryId,
      'title': activity.title,
      'order': activity.order,
    };
  }

  static LearningActivity activityFromMap(
    Map<String, Object?> data, {
    required String documentId,
    required String categoryId,
  }) {
    final activity = LearningActivity.fromJson(<String, Object?>{
      ...data,
      'id': _readStableId(data, documentId),
      'categoryId': data['categoryId'] ?? categoryId,
    });
    if (activity.id != documentId) {
      throw const FormatException('Activity id must match document id.');
    }
    if (activity.categoryId != categoryId) {
      throw const FormatException('Activity categoryId must match parent.');
    }
    return activity;
  }

  static Map<String, Object?> questionToMap(QuizQuestion question) {
    return <String, Object?>{
      'id': question.id,
      'categoryId': question.categoryId,
      'activityId': question.activityId,
      'type': _questionTypeToString(question.type),
      'statement': question.statement,
      'options': question.options.map(optionToMap).toList(growable: false),
      'correctAnswer': question.correctAnswer,
      'acceptedAnswers': question.acceptedAnswers,
      'feedback': question.feedback,
      'capacity': question.capacity,
      'difficulty': question.difficulty,
    };
  }

  static QuizQuestion questionFromMap(
    Map<String, Object?> data, {
    required String documentId,
    required String categoryId,
  }) {
    final question = QuizQuestion.fromJson(<String, Object?>{
      ...data,
      'id': _readStableId(data, documentId),
      'categoryId': data['categoryId'] ?? categoryId,
    });
    if (question.id != documentId) {
      throw const FormatException('Question id must match document id.');
    }
    if (question.categoryId != categoryId) {
      throw const FormatException('Question categoryId must match parent.');
    }
    return question;
  }

  static Map<String, Object?> optionToMap(QuizOption option) {
    return <String, Object?>{'id': option.id, 'text': option.text};
  }

  static Map<String, Object?> examConfigToMap(FinalExamConfig exam) {
    return <String, Object?>{
      'id': exam.id,
      'categoryId': exam.categoryId,
      'title': exam.title,
      'questionCount': exam.questionCount,
      'minimumQuestionsPerActivity': exam.minimumQuestionsPerActivity,
      'targetBasicQuestions': exam.targetDifficultyCounts['básica'] ?? 0,
      'targetIntermediateQuestions':
          exam.targetDifficultyCounts['intermedia'] ?? 0,
    };
  }

  static FinalExamConfig examConfigFromMap(
    Map<String, Object?> data, {
    required String documentId,
    required String categoryId,
  }) {
    if (documentId.trim().isEmpty) {
      throw const FormatException('Exam config document id is required.');
    }
    final id = _readString(data, 'id');
    final mappedCategoryId = _readString(data, 'categoryId');
    if (mappedCategoryId != categoryId) {
      throw const FormatException('Exam config categoryId must match parent.');
    }

    return FinalExamConfig(
      id: id,
      categoryId: mappedCategoryId,
      title: _readString(data, 'title'),
      questionCount: _readInt(data, 'questionCount'),
      minimumQuestionsPerActivity: _readInt(
        data,
        'minimumQuestionsPerActivity',
      ),
      targetDifficultyCounts: <String, int>{
        'básica': _readInt(data, 'targetBasicQuestions'),
        'intermedia': _readInt(data, 'targetIntermediateQuestions'),
      },
      order: FinalExamConfigs.relationsViolence.order,
    );
  }

  static String _readStableId(Map<String, Object?> data, String documentId) {
    final value = data['id'];
    if (value == null) {
      return documentId;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw const FormatException('Invalid content id.');
  }

  static String _readString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Invalid exam config "$key".');
  }

  static int _readInt(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    throw FormatException('Invalid exam config "$key".');
  }

  static String _categoryStatusToString(CategoryStatus status) {
    return switch (status) {
      CategoryStatus.available => 'available',
      CategoryStatus.comingSoon => 'comingSoon',
    };
  }

  static String _questionTypeToString(QuestionType type) {
    return switch (type) {
      QuestionType.multipleChoice => 'multipleChoice',
      QuestionType.trueFalse => 'trueFalse',
      QuestionType.fillBlank => 'fillBlank',
    };
  }
}
