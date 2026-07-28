import 'json_readers.dart';

class LessonPage {
  const LessonPage({
    required this.id,
    required this.order,
    required this.title,
    required this.body,
  });

  factory LessonPage.fromJson(Map<String, Object?> json) {
    final order = readInt(json, 'order');
    if (order < 1) {
      throw const FormatException('Lesson page order must be positive.');
    }

    return LessonPage(
      id: readString(json, 'id'),
      order: order,
      title: readString(json, 'title'),
      body: readString(json, 'body'),
    );
  }

  final String id;
  final int order;
  final String title;
  final String body;
}
