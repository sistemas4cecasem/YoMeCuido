import 'category_progress.dart';

enum PendingQuizAttemptSyncStatus {
  inProgress('inProgress'),
  abandonedPendingFinalization('abandonedPendingFinalization'),
  pendingSync('pendingSync'),
  syncing('syncing');

  const PendingQuizAttemptSyncStatus(this.value);

  final String value;

  static PendingQuizAttemptSyncStatus fromString(String value) {
    return switch (value) {
      'inProgress' => PendingQuizAttemptSyncStatus.inProgress,
      'abandonedPendingFinalization' =>
        PendingQuizAttemptSyncStatus.abandonedPendingFinalization,
      'pendingSync' => PendingQuizAttemptSyncStatus.pendingSync,
      'syncing' => PendingQuizAttemptSyncStatus.syncing,
      _ => PendingQuizAttemptSyncStatus.pendingSync,
    };
  }
}

class PendingQuizAttempt {
  const PendingQuizAttempt({
    required this.uid,
    required this.attemptId,
    required this.type,
    required this.categoryId,
    required this.lessonId,
    required this.activityId,
    required this.examId,
    required this.questionIds,
    required this.answers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.totalActivities,
    required this.startedAt,
    required this.completedAt,
    this.status = PendingQuizAttemptSyncStatus.pendingSync,
  });

  factory PendingQuizAttempt.fromJson(Map<String, Object?> json) {
    final answersJson = json['answers'] as List<Object?>? ?? const [];
    final completedAtRaw = json['completedAt'];
    return PendingQuizAttempt(
      uid: _readString(json, 'uid'),
      attemptId: _readString(json, 'attemptId'),
      type: QuizAttemptType.fromFirestore(_readString(json, 'type')),
      categoryId: _readString(json, 'categoryId'),
      lessonId: _readString(json, 'lessonId'),
      activityId: _readNullableString(json, 'activityId'),
      examId: _readNullableString(json, 'examId'),
      questionIds: List<String>.unmodifiable(
        (json['questionIds'] as List<Object?>? ?? const []).whereType<String>(),
      ),
      answers: List<CategoryProgressAnswer>.unmodifiable(
        answersJson.map((answer) {
          if (answer is! Map) {
            throw const FormatException('Invalid pending quiz answer object.');
          }
          final data = Map<Object?, Object?>.from(answer);
          return CategoryProgressAnswer(
            questionId: _readString(data, 'questionId'),
            answer: _readString(data, 'answer'),
            isCorrect: data['isCorrect'] == true,
            answeredAt: DateTime.parse(_readString(data, 'answeredAt')),
          );
        }),
      ),
      correctAnswers: _readInt(json, 'correctAnswers'),
      totalQuestions: _readInt(json, 'totalQuestions'),
      percentage: _readInt(json, 'percentage'),
      totalActivities: _readInt(json, 'totalActivities'),
      startedAt: DateTime.parse(_readString(json, 'startedAt')),
      completedAt: completedAtRaw == null
          ? null
          : DateTime.parse(_readString(json, 'completedAt')),
      status: PendingQuizAttemptSyncStatus.fromString(
        _readString(json, 'status'),
      ),
    );
  }

  final String uid;
  final String attemptId;
  final QuizAttemptType type;
  final String categoryId;
  final String lessonId;
  final String? activityId;
  final String? examId;
  final List<String> questionIds;
  final List<CategoryProgressAnswer> answers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final int totalActivities;
  final DateTime startedAt;
  final DateTime? completedAt;
  final PendingQuizAttemptSyncStatus status;

  bool get isInProgress => status == PendingQuizAttemptSyncStatus.inProgress;

  bool get isInterrupted {
    return status == PendingQuizAttemptSyncStatus.inProgress ||
        status == PendingQuizAttemptSyncStatus.abandonedPendingFinalization;
  }

  bool get isPendingSync {
    return status == PendingQuizAttemptSyncStatus.pendingSync ||
        status == PendingQuizAttemptSyncStatus.syncing;
  }

  PendingQuizAttempt finalized({
    required DateTime completedAt,
    PendingQuizAttemptSyncStatus status =
        PendingQuizAttemptSyncStatus.pendingSync,
  }) {
    return copyWith(completedAt: completedAt, status: status);
  }

  PendingQuizAttempt copyWith({
    List<CategoryProgressAnswer>? answers,
    int? correctAnswers,
    int? totalQuestions,
    int? percentage,
    DateTime? completedAt,
    PendingQuizAttemptSyncStatus? status,
  }) {
    return PendingQuizAttempt(
      uid: uid,
      attemptId: attemptId,
      type: type,
      categoryId: categoryId,
      lessonId: lessonId,
      activityId: activityId,
      examId: examId,
      questionIds: questionIds,
      answers: answers ?? this.answers,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      percentage: percentage ?? this.percentage,
      totalActivities: totalActivities,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'uid': uid,
      'attemptId': attemptId,
      'type': type.firestoreValue,
      'categoryId': categoryId,
      'lessonId': lessonId,
      'activityId': activityId,
      'examId': examId,
      'questionIds': questionIds,
      'answers': [
        for (final answer in answers)
          {
            'questionId': answer.questionId,
            'answer': answer.answer,
            'isCorrect': answer.isCorrect,
            'answeredAt': answer.answeredAt.toIso8601String(),
          },
      ],
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'percentage': percentage,
      'totalActivities': totalActivities,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status.value,
    };
  }
}

String _readString(Map<Object?, Object?> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Invalid pending quiz attempt "$key".');
}

String? _readNullableString(Map<Object?, Object?> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Invalid pending quiz attempt "$key".');
}

int _readInt(Map<Object?, Object?> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Invalid pending quiz attempt "$key".');
}
