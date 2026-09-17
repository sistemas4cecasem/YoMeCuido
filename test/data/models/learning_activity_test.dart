import 'dart:convert';
import 'dart:io';

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
      expect(activity.completion.takeaways, isEmpty);
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
      expect(activity.completion.takeaways, isEmpty);
    });

    test('decodes completion takeaways and keeps their order', () {
      final activity = LearningActivity.fromJson(const {
        'id': 'relations_violence_activity_01',
        'categoryId': 'relations_violence_digital',
        'title': 'Actividad 1',
        'order': 1,
        'completion': {
          'takeaways': ['Mensaje 1', 'Mensaje 2', 'Mensaje 3'],
        },
      });

      expect(activity.completion.takeaways, <String>[
        'Mensaje 1',
        'Mensaje 2',
        'Mensaje 3',
      ]);
    });

    test('decodes completion without takeaways as empty completion', () {
      final activity = LearningActivity.fromJson(const {
        'id': 'relations_violence_activity_01',
        'categoryId': 'relations_violence_digital',
        'title': 'Actividad 1',
        'order': 1,
        'completion': <String, Object?>{},
      });

      expect(activity.completion.takeaways, isEmpty);
    });

    test('accepts empty takeaways', () {
      final activity = LearningActivity.fromJson(const {
        'id': 'relations_violence_activity_01',
        'categoryId': 'relations_violence_digital',
        'title': 'Actividad 1',
        'order': 1,
        'completion': {'takeaways': <String>[]},
      });

      expect(activity.completion.takeaways, isEmpty);
    });

    test('decodes invalid completion as empty completion', () {
      final activity = LearningActivity.fromJson(const {
        'id': 'relations_violence_activity_01',
        'categoryId': 'relations_violence_digital',
        'title': 'Actividad 1',
        'order': 1,
        'completion': {
          'takeaways': ['Mensaje 1', 2, 'Mensaje 3'],
        },
      });

      expect(activity.completion.takeaways, isEmpty);
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

    test('seed activities define exactly three completion takeaways', () async {
      final directory = Directory('tool/seed/content');
      final files =
          directory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('_activities.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      var activityCount = 0;

      expect(files, isNotEmpty);

      for (final file in files) {
        final decoded = jsonDecode(await file.readAsString());
        final activities = decoded is List<Object?>
            ? decoded
            : (decoded as Map<String, Object?>)['activities'] as List<Object?>;

        for (final item in activities) {
          final activity = item! as Map<String, Object?>;
          final completion = activity['completion'];

          expect(
            completion,
            isA<Map<String, Object?>>(),
            reason: '${file.path}:${activity['id']} requires completion.',
          );

          final takeaways = (completion! as Map<String, Object?>)['takeaways'];

          expect(
            takeaways,
            isA<List<Object?>>(),
            reason: '${file.path}:${activity['id']} requires takeaways.',
          );
          expect(
            takeaways,
            hasLength(3),
            reason:
                '${file.path}:${activity['id']} must define exactly 3 takeaways.',
          );

          for (final takeaway in takeaways as List<Object?>) {
            expect(
              takeaway,
              isA<String>(),
              reason:
                  '${file.path}:${activity['id']} takeaways must be strings.',
            );
            expect(
              (takeaway! as String).trim(),
              isNotEmpty,
              reason:
                  '${file.path}:${activity['id']} takeaways cannot be empty.',
            );
          }

          activityCount += 1;
        }
      }

      expect(activityCount, 96);
    });
  });
}
