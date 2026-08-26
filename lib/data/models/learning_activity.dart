import 'json_readers.dart';

class LearningActivity {
  const LearningActivity({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.order,
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
    );
  }

  final String id;
  final String categoryId;
  final String title;
  final int order;
}
