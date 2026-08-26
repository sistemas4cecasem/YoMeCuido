import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningActivity', () {
    test('can be constructed with a stable id and category relationship', () {
      const activity = LearningActivity(
        id: 'relations_violence_activity_01',
        categoryId: 'relations_violence_digital',
        title: 'Actividad 1',
        order: 1,
      );

      expect(activity.id, 'relations_violence_activity_01');
      expect(activity.categoryId, 'relations_violence_digital');
      expect(activity.title, 'Actividad 1');
      expect(activity.order, 1);
    });

    test('decodes from json and keeps order', () {
      final activity = LearningActivity.fromJson(const {
        'id': 'relations_violence_activity_01',
        'categoryId': 'relations_violence_digital',
        'title': 'Actividad 1',
        'order': 1,
      });

      expect(activity.id, 'relations_violence_activity_01');
      expect(activity.categoryId, 'relations_violence_digital');
      expect(activity.order, 1);
    });

    test('rejects non-positive order', () {
      expect(
        () => LearningActivity.fromJson(const {
          'id': 'relations_violence_activity_01',
          'categoryId': 'relations_violence_digital',
          'title': 'Actividad 1',
          'order': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
