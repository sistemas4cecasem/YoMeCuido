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

  test('privacy notice distinguishes installed SDK from future reporting', () {
    final notice =
        jsonDecode(File('assets/data/privacy_notice.json').readAsStringSync())
            as Map<String, Object?>;
    final sections = notice['sections']! as List<Object?>;
    final bodies = sections
        .cast<Map<String, Object?>>()
        .map((section) => section['body']! as String)
        .join('\n');
    expect(notice['intro'], contains('[PENDIENTE DE DEFINIR]'));
    expect(bodies, contains('SDK Firebase Crashlytics está instalado'));
    expect(bodies, contains('envío automático de informes desactivado'));
    expect(bodies, contains('pruebas técnicas aisladas y autorizadas'));
    expect(bodies, contains('un único diagnóstico sintético'));
    expect(bodies, contains('la recopilación vuelve a desactivarse'));
    expect(bodies, contains('guardar informes técnicos en el dispositivo'));
    expect(bodies, contains('90 días antes de iniciar su eliminación'));
    expect(bodies, contains('no elimina esos informes del proveedor'));
    expect(bodies, contains('No integra Firebase Analytics'));
  });
}
