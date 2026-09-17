import 'json_readers.dart';

class LearningActivity {
  const LearningActivity({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.order,
    this.completion = const ActivityCompletion(),
  });

  factory LearningActivity.fromJson(Map<String, Object?> json) {
    final order = readInt(json, 'order');
    if (order < 1) {
      throw const FormatException('Learning activity order must be positive.');
    }

    return LearningActivity(
      id: readString(json, 'id'),
      categoryId: readString(json, 'categoryId'),
      title: readString(json, 'title'),
      order: order,
      completion: ActivityCompletion.fromJson(json['completion']),
    );
  }

  final String id;
  final String categoryId;
  final String title;
  final int order;
  final ActivityCompletion completion;
}

class ActivityCompletion {
  const ActivityCompletion({this.takeaways = const <String>[]});

  factory ActivityCompletion.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const ActivityCompletion();
    }

    final takeaways = _readOptionalTakeaways(value);
    return ActivityCompletion(takeaways: takeaways);
  }

  final List<String> takeaways;

  Map<String, Object?> toJson() {
    return <String, Object?>{'takeaways': takeaways};
  }

  static List<String> _readOptionalTakeaways(Map<String, Object?> json) {
    final value = json['takeaways'];
    if (value == null) {
      return const <String>[];
    }
    if (value is! List<Object?>) {
      return const <String>[];
    }

    final takeaways = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty) {
        return const <String>[];
      }
      takeaways.add(item);
    }

    return List<String>.unmodifiable(takeaways);
  }
}
