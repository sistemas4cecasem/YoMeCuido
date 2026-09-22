import 'json_readers.dart';

class OfflineActivityOption {
  const OfflineActivityOption({required this.id, required this.text});

  factory OfflineActivityOption.fromJson(Map<String, Object?> json) {
    final id = readString(json, 'id').trim();
    final text = readString(json, 'text').trim();
    if (id.isEmpty || text.isEmpty) {
      throw const FormatException('Offline option id and text are required.');
    }
    return OfflineActivityOption(id: id, text: text);
  }

  final String id;
  final String text;
}

class OfflineActivityQuestion {
  const OfflineActivityQuestion({
    required this.id,
    required this.statement,
    required this.options,
    required this.correctAnswer,
  });

  factory OfflineActivityQuestion.fromJson(Map<String, Object?> json) {
    final id = readString(json, 'id').trim();
    final statement = readString(json, 'statement').trim();
    final correctAnswer = readString(json, 'correctAnswer').trim();
    final options = _readOptions(json);
    final optionIds = options.map((option) => option.id).toSet();

    if (id.isEmpty || statement.isEmpty) {
      throw const FormatException('Offline question id and text are required.');
    }
    if (options.length != 4) {
      throw const FormatException(
        'Offline questions require exactly 4 options.',
      );
    }
    if (optionIds.length != options.length) {
      throw const FormatException(
        'Offline question option ids must be unique.',
      );
    }
    if (!optionIds.contains(correctAnswer)) {
      throw const FormatException(
        'Offline correct answer must match an option id.',
      );
    }

    return OfflineActivityQuestion(
      id: id,
      statement: statement,
      options: options,
      correctAnswer: correctAnswer,
    );
  }

  final String id;
  final String statement;
  final List<OfflineActivityOption> options;
  final String correctAnswer;

  bool isCorrectAnswer(String optionId) => optionId == correctAnswer;

  OfflineActivityQuestion copyWith({List<OfflineActivityOption>? options}) {
    return OfflineActivityQuestion(
      id: id,
      statement: statement,
      options: options ?? this.options,
      correctAnswer: correctAnswer,
    );
  }

  static List<OfflineActivityOption> _readOptions(Map<String, Object?> json) {
    final value = json['options'];
    if (value is! List<Object?>) {
      throw const FormatException('Invalid offline options list.');
    }

    return value
        .map((item) {
          if (item is Map<String, Object?>) {
            return OfflineActivityOption.fromJson(item);
          }
          throw const FormatException('Invalid offline option object.');
        })
        .toList(growable: false);
  }
}
