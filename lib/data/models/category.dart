import 'json_readers.dart';

enum CategoryStatus { available, comingSoon }

class Category {
  const Category({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.status,
    required this.isEnabled,
    required this.indicators,
    required this.objectives,
    this.warning,
    this.lessonId,
  });

  factory Category.fromJson(Map<String, Object?> json) {
    final status = _readStatus(readString(json, 'status'));
    final isEnabled = readBool(json, 'isEnabled');
    final lessonId = readOptionalString(json, 'lessonId');

    if (isEnabled && status != CategoryStatus.available) {
      throw const FormatException('Enabled categories must be available.');
    }
    if (!isEnabled && status == CategoryStatus.available) {
      throw const FormatException('Disabled categories cannot be available.');
    }
    if (isEnabled && (lessonId == null || lessonId.trim().isEmpty)) {
      throw const FormatException('Enabled categories require a lessonId.');
    }

    return Category(
      id: readString(json, 'id'),
      title: readString(json, 'title'),
      description: readString(json, 'description'),
      iconName: readString(json, 'iconName'),
      status: status,
      isEnabled: isEnabled,
      indicators: readStringList(json, 'indicators'),
      objectives: readStringList(json, 'objectives'),
      warning: readOptionalString(json, 'warning'),
      lessonId: lessonId,
    );
  }

  final String id;
  final String title;
  final String description;
  final String iconName;
  final CategoryStatus status;
  final bool isEnabled;
  final List<String> indicators;
  final List<String> objectives;
  final String? warning;
  final String? lessonId;

  bool get isComingSoon => status == CategoryStatus.comingSoon;

  static CategoryStatus _readStatus(String value) {
    return switch (value) {
      'available' => CategoryStatus.available,
      'comingSoon' => CategoryStatus.comingSoon,
      _ => throw FormatException('Unknown category status "$value".'),
    };
  }
}
