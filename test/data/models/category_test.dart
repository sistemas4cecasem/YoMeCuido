import 'package:demo_yomecuido/data/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Category', () {
    test('reads parentCategoryId from JSON', () {
      final category = Category.fromJson(<String, Object?>{
        'id': 'relations_violence_digital',
        'parentCategoryId': ParentCategoryIds.digitalSecurity,
        'title': 'Relaciones y violencia digital',
        'description': 'Descripcion.',
        'iconName': 'shield_outlined',
        'status': 'available',
        'isEnabled': true,
        'indicators': <String>['6 actividades'],
        'objectives': <String>['Reconocer riesgos.'],
        'lessonId': 'relations_violence',
      });

      expect(category.parentCategoryId, ParentCategoryIds.digitalSecurity);
    });

    test('defaults legacy categories to digital security', () {
      final category = Category.fromJson(<String, Object?>{
        'id': 'relations_violence_digital',
        'title': 'Relaciones y violencia digital',
        'description': 'Descripcion.',
        'iconName': 'shield_outlined',
        'status': 'available',
        'isEnabled': true,
        'indicators': <String>['6 actividades'],
        'objectives': <String>['Reconocer riesgos.'],
        'lessonId': 'relations_violence',
      });

      expect(category.parentCategoryId, ParentCategoryIds.digitalSecurity);
    });
  });
}
