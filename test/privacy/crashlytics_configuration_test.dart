import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native reporting is disabled in the common Android manifest', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final setting = RegExp(
      r'<meta-data\s+android:name="firebase_crashlytics_collection_enabled"'
      r'\s+android:value="false"\s*/>',
    );
    expect(setting.allMatches(manifest), hasLength(1));
    for (final mode in ['debug', 'profile']) {
      final overlay = File(
        'android/app/src/$mode/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        overlay,
        isNot(contains('firebase_crashlytics_collection_enabled')),
      );
    }
  });

  test('privacy notice uses user-facing wording and the provided contact', () {
    final notice =
        jsonDecode(File('assets/data/privacy_notice.json').readAsStringSync())
            as Map<String, Object?>;
    final sections = notice['sections']! as List<Object?>;
    final bodies = sections
        .cast<Map<String, Object?>>()
        .map((section) => section['body']! as String)
        .join('\n');
    expect(notice['title'], 'Privacidad en YoMeCuido');
    expect(notice['intro'], contains('qué opciones tienes sobre tus datos'));
    expect(
      sections.cast<Map<String, Object?>>().map((section) => section['title']),
      [
        'Datos que utilizamos',
        'Para qué utilizamos tus datos',
        'Información visible para otros usuarios',
        'Servicios de terceros',
        'Eliminación y conservación',
        'Responsable y contacto',
      ],
    );
    expect(bodies, contains('servicios tecnológicos de terceros'));
    expect(bodies, contains('Perfil > Eliminar cuenta'));
    expect(bodies, contains('https://cecasem.com/'));
    final visibleContent = '${notice['title']}\n${notice['intro']}\n$bodies';
    for (final internalDetail in [
      'Firebase',
      'Firestore',
      'App Check',
      'Crashlytics',
      'SDK',
      'usernameNormalized',
      'conectividad',
      'lecturas',
      'escrituras',
      'backend',
      '[PENDIENTE DE DEFINIR]',
    ]) {
      expect(visibleContent, isNot(contains(internalDetail)));
    }
  });
}
