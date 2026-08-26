import 'json_readers.dart';

enum QuestionType { multipleChoice, trueFalse, fillBlank }

class QuizOption {
  const QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, Object?> json) {
    return QuizOption(
      id: readString(json, 'id'),
      text: readString(json, 'text'),
    );
  }

  final String id;
  final String text;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.categoryId,
    required this.activityId,
    required this.type,
    required this.statement,
    required this.options,
    required this.correctAnswer,
    required this.acceptedAnswers,
    required this.feedback,
    required this.capacity,
    required this.difficulty,
  });

  factory QuizQuestion.fromJson(Map<String, Object?> json) {
    final type = _readType(readString(json, 'type'));
    final options = _readOptions(json);
    final correctAnswer = readString(json, 'correctAnswer');
    final acceptedAnswers = _readAcceptedAnswers(json, correctAnswer);

    if (type == QuestionType.fillBlank) {
      if (options.isNotEmpty) {
        throw const FormatException(
          'Fill blank questions cannot have options.',
        );
      }
    } else {
      if (options.isEmpty) {
        throw const FormatException('Choice questions require options.');
      }
      if (!options.any((option) => option.id == correctAnswer)) {
        throw const FormatException('Correct answer must match an option id.');
      }
    }

    return QuizQuestion(
      id: readString(json, 'id'),
      categoryId: readString(json, 'categoryId'),
      activityId: readString(json, 'activityId'),
      type: type,
      statement: readString(json, 'statement'),
      options: options,
      correctAnswer: correctAnswer,
      acceptedAnswers: acceptedAnswers,
      feedback: readString(json, 'feedback'),
      capacity: readString(json, 'capacity'),
      difficulty: readString(json, 'difficulty'),
    );
  }

  final String id;
  final String categoryId;
  final String activityId;
  final QuestionType type;
  final String statement;
  final List<QuizOption> options;
  final String correctAnswer;
  final List<String> acceptedAnswers;
  final String feedback;
  final String capacity;
  final String difficulty;

  bool isCorrectAnswer(String answer) {
    if (type == QuestionType.fillBlank) {
      final normalizedAnswer = _normalizeFillBlankAnswer(answer);
      return acceptedAnswers.any(
        (acceptedAnswer) =>
            _normalizeFillBlankAnswer(acceptedAnswer) == normalizedAnswer,
      );
    }

    return answer.trim() == correctAnswer;
  }

  static QuestionType _readType(String value) {
    return switch (value) {
      'multipleChoice' => QuestionType.multipleChoice,
      'trueFalse' => QuestionType.trueFalse,
      'fillBlank' => QuestionType.fillBlank,
      _ => throw FormatException('Unknown question type "$value".'),
    };
  }

  static List<QuizOption> _readOptions(Map<String, Object?> json) {
    final value = json['options'];
    if (value == null) {
      return const <QuizOption>[];
    }
    if (value is! List<Object?>) {
      throw const FormatException('Invalid "options" list.');
    }

    return value
        .map((item) {
          if (item is Map<String, Object?>) {
            return QuizOption.fromJson(item);
          }

          throw const FormatException('Invalid option object.');
        })
        .toList(growable: false);
  }

  static List<String> _readAcceptedAnswers(
    Map<String, Object?> json,
    String correctAnswer,
  ) {
    final value = json['acceptedAnswers'];
    if (value == null) {
      return <String>[correctAnswer];
    }

    return readStringList(json, 'acceptedAnswers');
  }

  static String _normalizeFillBlankAnswer(String value) {
    return value.trim().toLowerCase();
  }
}
