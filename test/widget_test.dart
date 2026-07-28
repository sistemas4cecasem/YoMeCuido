import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the technical foundation route', (tester) async {
    await tester.pumpWidget(const YoMeCuidoApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.foundationTitle), findsOneWidget);
    expect(find.text(AppStrings.foundationDescription), findsOneWidget);
  });
}
