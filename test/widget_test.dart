import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/splash/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeContentRepository repository;

  setUp(() {
    repository = _FakeContentRepository();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(YoMeCuidoApp(contentRepository: repository));
    await tester.pumpAndSettle();
  }

  testWidgets('la bienvenida muestra logo, frase y botón', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('welcome_logo')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.fit == BoxFit.contain &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                WelcomeScreen.logoAssetPath,
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    expect(find.text(AppStrings.start), findsOneWidget);
  });

  testWidgets('el botón Comenzar abre categorías', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.categoriesTitle), findsOneWidget);
    expect(repository.loadCategoriesCalls, 1);
  });

  testWidgets('se muestran ocho categorías y solo una habilitada', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();

    for (final category in repository.categories) {
      expect(find.text(category.title), findsOneWidget);
    }

    final enabled = repository.categories.where((category) {
      return category.isEnabled;
    });
    final locked = repository.categories.where((category) {
      return !category.isEnabled;
    });

    expect(enabled, hasLength(1));
    expect(find.text(AppStrings.comingSoon), findsNWidgets(locked.length));
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('las categorías bloqueadas no navegan', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Protección de cuentas y autenticación'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.temporaryDetailBody), findsNothing);
    expect(find.text(AppStrings.categoriesTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoonSnackBar), findsOneWidget);
  });

  testWidgets('la categoría habilitada permite avanzar', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relaciones y violencia digital'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.temporaryDetailBody), findsOneWidget);
    expect(find.text('Relaciones y violencia digital'), findsWidgets);
  });
}

class _FakeContentRepository implements ContentRepository {
  int loadCategoriesCalls = 0;

  final categories = const <Category>[
    Category(
      id: 'relations_violence_digital',
      title: 'Relaciones y violencia digital',
      description: 'Contenido disponible para la demo.',
      iconName: 'shield_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>[],
      objectives: <String>[],
      lessonId: 'relations_violence',
    ),
    Category(
      id: 'account_protection_authentication',
      title: 'Protección de cuentas y autenticación',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'lock_outline',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'device_app_security',
      title: 'Seguridad de dispositivos y aplicaciones',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'phone_android_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'personal_data_privacy_identity',
      title: 'Datos personales, privacidad e identidad',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'badge_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'phishing_social_engineering',
      title: 'Engaños, phishing e ingeniería social',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'mark_email_unread_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'digital_payments_consumption',
      title: 'Pagos, transferencias, compras y consumo digital',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'credit_card_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'information_misinformation_ai',
      title: 'Información, desinformación e inteligencia artificial',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'fact_check_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
    Category(
      id: 'incident_response_recovery',
      title: 'Respuesta y recuperación ante incidentes',
      description: 'Esta categoría estará disponible próximamente.',
      iconName: 'health_and_safety_outlined',
      status: CategoryStatus.comingSoon,
      isEnabled: false,
      indicators: <String>[],
      objectives: <String>[],
    ),
  ];

  @override
  Future<List<Category>> loadCategories() async {
    loadCategoriesCalls += 1;
    return categories;
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId) {
    throw UnimplementedError();
  }
}
