import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryProgressStatus {
  notStarted('notStarted'),
  inProgress('inProgress'),
  completed('completed');

  const CategoryProgressStatus(this.firestoreValue);

  final String firestoreValue;

  static CategoryProgressStatus fromFirestore(String value) {
    return switch (value) {
      'notStarted' => CategoryProgressStatus.notStarted,
      'inProgress' => CategoryProgressStatus.inProgress,
      'completed' => CategoryProgressStatus.completed,
      _ => throw FormatException('Unknown category progress status "$value".'),
    };
  }
}

enum ActivityProgressStatus {
  notStarted('notStarted'),
  inProgress('inProgress'),
  completed('completed');

  const ActivityProgressStatus(this.firestoreValue);

  final String firestoreValue;

  static ActivityProgressStatus fromFirestore(String value) {
    return switch (value) {
      'notStarted' => ActivityProgressStatus.notStarted,
      'inProgress' => ActivityProgressStatus.inProgress,
      'completed' => ActivityProgressStatus.completed,
      _ => throw FormatException('Unknown activity progress status "$value".'),
    };
  }
}

enum QuizAttemptType {
  activity('activity'),
  exam('exam');

  const QuizAttemptType(this.firestoreValue);

  final String firestoreValue;

  static QuizAttemptType fromFirestore(String value) {
    return switch (value) {
      'activity' => QuizAttemptType.activity,
      'exam' => QuizAttemptType.exam,
      _ => throw FormatException('Unknown quiz attempt type "$value".'),
    };
  }
}

class CategoryProgressAnswer {
  const CategoryProgressAnswer({
    required this.questionId,
    required this.answer,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory CategoryProgressAnswer.fromFirestore(Map<String, dynamic> data) {
    return CategoryProgressAnswer(
      questionId: _readString(data, 'questionId'),
      answer: _readString(data, 'answer'),
      isCorrect: _readBool(data, 'isCorrect'),
      answeredAt: _readTimestamp(data, 'answeredAt'),
    );
  }

  final String questionId;
  final String answer;
  final bool isCorrect;
  final DateTime answeredAt;

  Map<String, dynamic> toFirestore() {
    return {
      'questionId': questionId,
      'answer': answer,
      'isCorrect': isCorrect,
      'answeredAt': Timestamp.fromDate(answeredAt),
    };
  }
}

class ActivityProgressRecord {
  const ActivityProgressRecord({
    required this.activityId,
    required this.status,
    required this.attemptCount,
    required this.bestCorrectAnswers,
    required this.bestTotalQuestions,
    required this.bestPercentage,
    required this.lastAttemptAt,
    required this.completedAt,
    required this.updatedAt,
  });

  factory ActivityProgressRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Activity progress document is empty.');
    }

    return ActivityProgressRecord.fromMap(data);
  }

  factory ActivityProgressRecord.fromMap(Map<String, dynamic> data) {
    return ActivityProgressRecord(
      activityId: _readString(data, 'activityId'),
      status: ActivityProgressStatus.fromFirestore(_readString(data, 'status')),
      attemptCount: _readInt(data, 'attemptCount'),
      bestCorrectAnswers: _readInt(data, 'bestCorrectAnswers'),
      bestTotalQuestions: _readInt(data, 'bestTotalQuestions'),
      bestPercentage: _readInt(data, 'bestPercentage'),
      lastAttemptAt: _readNullableTimestamp(data, 'lastAttemptAt'),
      completedAt: _readNullableTimestamp(data, 'completedAt'),
      updatedAt: _readTimestamp(data, 'updatedAt'),
    );
  }

  final String activityId;
  final ActivityProgressStatus status;
  final int attemptCount;
  final int bestCorrectAnswers;
  final int bestTotalQuestions;
  final int bestPercentage;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'status': status.firestoreValue,
      'attemptCount': attemptCount,
      'bestCorrectAnswers': bestCorrectAnswers,
      'bestTotalQuestions': bestTotalQuestions,
      'bestPercentage': bestPercentage,
      'lastAttemptAt': _nullableTimestamp(lastAttemptAt),
      'completedAt': _nullableTimestamp(completedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.activityId,
    required this.questionIds,
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.startedAt,
    required this.completedAt,
  });

  factory QuizAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Quiz attempt document is empty.');
    }

    return QuizAttempt.fromMap(id: snapshot.id, data: data);
  }

  factory QuizAttempt.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final answersData = _readMap(data, 'answers');
    final answers = <CategoryProgressAnswer>[];
    for (final entry in answersData.entries) {
      final answerData = entry.value;
      if (answerData is! Map) {
        throw FormatException('Invalid attempt answer "${entry.key}".');
      }
      answers.add(
        CategoryProgressAnswer.fromFirestore(
          Map<String, dynamic>.from(answerData),
        ),
      );
    }

    return QuizAttempt(
      id: id,
      type: QuizAttemptType.fromFirestore(_readString(data, 'type')),
      categoryId: _readString(data, 'categoryId'),
      activityId: _readString(data, 'activityId'),
      questionIds: _readStringList(data, 'questionIds'),
      answers: List<CategoryProgressAnswer>.unmodifiable(answers),
      correctAnswers: _readInt(data, 'correctAnswers'),
      totalQuestions: _readInt(data, 'totalQuestions'),
      percentage: _readInt(data, 'percentage'),
      startedAt: _readTimestamp(data, 'startedAt'),
      completedAt: _readNullableTimestamp(data, 'completedAt'),
    );
  }

  final String id;
  final QuizAttemptType type;
  final String categoryId;
  final String activityId;
  final List<String> questionIds;
  final List<CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final DateTime startedAt;
  final DateTime? completedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.firestoreValue,
      'categoryId': categoryId,
      'activityId': activityId,
      'questionIds': questionIds,
      'answers': {
        for (final answer in answers) answer.questionId: answer.toFirestore(),
      },
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'percentage': percentage,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': _nullableTimestamp(completedAt),
    };
  }
}

class CategoryProgressRecord {
  const CategoryProgressRecord({
    required this.categoryId,
    required this.lessonId,
    required this.status,
    required this.viewedLessonPageIds,
    required this.completedActivityIds,
    required this.totalLessonPages,
    required this.totalActivities,
    required this.startedAt,
    required this.lastActivityAt,
    required this.completedAt,
    required this.updatedAt,
    required this.activities,
  });

  factory CategoryProgressRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    Map<String, ActivityProgressRecord> activities =
        const <String, ActivityProgressRecord>{},
  }) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Category progress document is empty.');
    }

    return CategoryProgressRecord.fromMap(data, activities: activities);
  }

  factory CategoryProgressRecord.fromMap(
    Map<String, dynamic> data, {
    Map<String, ActivityProgressRecord> activities =
        const <String, ActivityProgressRecord>{},
  }) {
    return CategoryProgressRecord(
      categoryId: _readString(data, 'categoryId'),
      lessonId: _readString(data, 'lessonId'),
      status: CategoryProgressStatus.fromFirestore(_readString(data, 'status')),
      viewedLessonPageIds: _readStringList(data, 'viewedLessonPageIds'),
      completedActivityIds: _readStringList(data, 'completedActivityIds'),
      totalLessonPages: _readInt(data, 'totalLessonPages'),
      totalActivities: _readInt(data, 'totalActivities'),
      startedAt: _readTimestamp(data, 'startedAt'),
      lastActivityAt: _readNullableTimestamp(data, 'lastActivityAt'),
      completedAt: _readNullableTimestamp(data, 'completedAt'),
      updatedAt: _readTimestamp(data, 'updatedAt'),
      activities: Map<String, ActivityProgressRecord>.unmodifiable(activities),
    );
  }

  final String categoryId;
  final String lessonId;
  final CategoryProgressStatus status;
  final List<String> viewedLessonPageIds;
  final List<String> completedActivityIds;
  final int totalLessonPages;
  final int totalActivities;
  final DateTime startedAt;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final Map<String, ActivityProgressRecord> activities;

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'lessonId': lessonId,
      'status': status.firestoreValue,
      'viewedLessonPageIds': viewedLessonPageIds,
      'completedActivityIds': completedActivityIds,
      'totalLessonPages': totalLessonPages,
      'totalActivities': totalActivities,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastActivityAt': _nullableTimestamp(lastActivityAt),
      'completedAt': _nullableTimestamp(completedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

Timestamp? _nullableTimestamp(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}

String _readString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Invalid category progress "$key".');
}

bool _readBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Invalid category progress "$key".');
}

int _readInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Invalid category progress "$key".');
}

DateTime _readTimestamp(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) {
    return value.toDate();
  }
  throw FormatException('Invalid category progress "$key".');
}

DateTime? _readNullableTimestamp(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  throw FormatException('Invalid category progress "$key".');
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! List<Object?>) {
    throw FormatException('Invalid category progress "$key".');
  }

  return List<String>.unmodifiable(
    value.map((item) {
      if (item is String && item.trim().isNotEmpty) {
        return item;
      }
      throw FormatException('Invalid category progress "$key" item.');
    }),
  );
}

Map<String, dynamic> _readMap(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('Invalid category progress "$key".');
}
