import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/features/privacy/privacy_notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(393, 873),
    const Size(412, 915),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'privacy scrolls without overflow at $size with text scale $textScale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var deleteCalls = 0;

          await tester.runAsync(() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.data(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                  ),
                  child: child!,
                ),
                home: PrivacyNoticeScreen(
                  onDeleteAccount: () => deleteCalls += 1,
                ),
              ),
            );
            await rootBundle.loadString('assets/data/privacy_notice.json');
          });
          await tester.pumpAndSettle();
          expect(find.text('Privacidad en YoMeCuido'), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final title in [
            'Datos que utilizamos',
            'Para qué utilizamos tus datos',
            'Información visible para otros usuarios',
            'Servicios de terceros',
            'Eliminación y conservación',
            'Responsable y contacto',
          ]) {
            await tester.scrollUntilVisible(find.text(title), 200);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(find.textContaining('https://cecasem.com/'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.widgetWithText(OutlinedButton, AppStrings.deleteAccount),
            200,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(deleteCalls, 0);
          await tester.tap(find.text(AppStrings.deleteAccount));
          await tester.pumpAndSettle();
          expect(deleteCalls, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
