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

class CategoryProgressAnswer {
  const CategoryProgressAnswer({
    required this.answer,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory CategoryProgressAnswer.fromFirestore(Map<String, dynamic> data) {
    return CategoryProgressAnswer(
      answer: _readString(data, 'answer'),
      isCorrect: _readBool(data, 'isCorrect'),
      answeredAt: _readTimestamp(data, 'answeredAt'),
    );
  }

  final String answer;
  final bool isCorrect;
  final DateTime answeredAt;

  Map<String, dynamic> toFirestore() {
    return {
      'answer': answer,
      'isCorrect': isCorrect,
      'answeredAt': Timestamp.fromDate(answeredAt),
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
    required this.correctAnswers,
    required this.totalLessonPages,
    required this.totalActivities,
    required this.attemptCount,
    required this.startedAt,
    required this.lastActivityAt,
    required this.completedAt,
    required this.updatedAt,
    required this.latestAnswers,
  });

  factory CategoryProgressRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Category progress document is empty.');
    }

    return CategoryProgressRecord.fromMap(data);
  }

  factory CategoryProgressRecord.fromMap(Map<String, dynamic> data) {
    final latestAnswers = <String, CategoryProgressAnswer>{};
    final latestAnswersData = _readMap(data, 'latestAnswers');
    for (final entry in latestAnswersData.entries) {
      final answerData = entry.value;
      if (answerData is! Map) {
        throw FormatException('Invalid answer entry "${entry.key}".');
      }
      latestAnswers[entry.key] = CategoryProgressAnswer.fromFirestore(
        Map<String, dynamic>.from(answerData),
      );
    }

    return CategoryProgressRecord(
      categoryId: _readString(data, 'categoryId'),
      lessonId: _readString(data, 'lessonId'),
      status: CategoryProgressStatus.fromFirestore(_readString(data, 'status')),
      viewedLessonPageIds: _readStringList(data, 'viewedLessonPageIds'),
      completedActivityIds: _readStringList(data, 'completedActivityIds'),
      correctAnswers: _readInt(data, 'correctAnswers'),
      totalLessonPages: _readInt(data, 'totalLessonPages'),
      totalActivities: _readInt(data, 'totalActivities'),
      attemptCount: _readInt(data, 'attemptCount'),
      startedAt: _readTimestamp(data, 'startedAt'),
      lastActivityAt: _readNullableTimestamp(data, 'lastActivityAt'),
      completedAt: _readNullableTimestamp(data, 'completedAt'),
      updatedAt: _readTimestamp(data, 'updatedAt'),
      latestAnswers: Map<String, CategoryProgressAnswer>.unmodifiable(
        latestAnswers,
      ),
    );
  }

  final String categoryId;
  final String lessonId;
  final CategoryProgressStatus status;
  final List<String> viewedLessonPageIds;
  final List<String> completedActivityIds;
  final int correctAnswers;
  final int totalLessonPages;
  final int totalActivities;
  final int attemptCount;
  final DateTime startedAt;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final Map<String, CategoryProgressAnswer> latestAnswers;

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'lessonId': lessonId,
      'status': status.firestoreValue,
      'viewedLessonPageIds': viewedLessonPageIds,
      'completedActivityIds': completedActivityIds,
      'correctAnswers': correctAnswers,
      'totalLessonPages': totalLessonPages,
      'totalActivities': totalActivities,
      'attemptCount': attemptCount,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastActivityAt': _nullableTimestamp(lastActivityAt),
      'completedAt': _nullableTimestamp(completedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'latestAnswers': latestAnswers.map((key, value) {
        return MapEntry(key, value.toFirestore());
      }),
    };
  }

  static Timestamp? _nullableTimestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }
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
