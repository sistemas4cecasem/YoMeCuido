import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_colors.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/local_content_repository.dart';
import 'package:demo_yomecuido/shared/widgets/answer_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository contentRepository;

  setUpAll(() async {
    final localRepository = LocalContentRepository();
    final categories = await localRepository.loadCategories();
    final lessonPages = await localRepository.loadLessonPages(
      LocalContentRepository.relationsViolenceCategoryId,
    );
    final quizQuestions = await localRepository.loadQuizQuestions(
      LocalContentRepository.relationsViolenceCategoryId,
    );

    contentRepository = _CachedContentRepository(
      categories: categories,
      lessonPages: lessonPages,
      quizQuestions: quizQuestions,
    );
  });

  const sizes = <Size>[Size(360, 640), Size(393, 873), Size(412, 915)];

  test('paletas clara y oscura mantienen contrastes principales', () {
    for (final palette in <AppPalette>[AppPalette.light, AppPalette.dark]) {
      expect(
        _contrast(palette.textPrimary, palette.background),
        greaterThan(7),
      );
      expect(_contrast(palette.textMuted, palette.surface), greaterThan(4.5));
      expect(_contrast(palette.purple, palette.background), greaterThan(3));
      expect(_contrast(Colors.white, palette.purple), greaterThan(4.5));
      expect(_contrast(palette.error, palette.surface), greaterThan(4.5));
      expect(_contrast(palette.success, palette.surface), greaterThan(4.5));
      expect(palette.orange, isNot(palette.purple));
    }
  });

  for (final size in sizes) {
    testWidgets('flujo principal sin overflow en ${size.width.toInt()}x'
        '${size.height.toInt()} claro', (tester) async {
      await _configureView(tester, size: size, brightness: Brightness.light);

      await _pumpDemo(tester, contentRepository);
      _expectNoFlutterException(tester);
      _expectPrimaryButtonTarget(tester, AppStrings.start);

      await _openCategories(tester);
      _expectNoFlutterException(tester);
      expect(find.text(AppStrings.comingSoon), findsNWidgets(7));
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      await _openDetail(tester);
      _expectNoFlutterException(tester);
      _expectPrimaryButtonTarget(tester, AppStrings.startLesson);

      await _openLessonLastPage(tester);
      _expectNoFlutterException(tester);
      _expectPrimaryButtonTarget(tester, AppStrings.startActivities);

      await _openQuiz(tester);
      _expectNoFlutterException(tester);
      _expectPrimaryButtonTarget(tester, AppStrings.submitAnswer);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
            )
            .enabled,
        isFalse,
      );

      await _answerActivity(tester, 1);
      _expectNoFlutterException(tester);
      expect(
        find.text(AppStrings.correct).evaluate().isNotEmpty ||
            find.text(AppStrings.reviewAnswer).evaluate().isNotEmpty,
        isTrue,
      );
    });
  }

  testWidgets('flujo completo tolera texto escalado y animaciones reducidas', (
    tester,
  ) async {
    await _configureView(
      tester,
      size: const Size(360, 640),
      brightness: Brightness.dark,
      textScale: 1.6,
      disableAnimations: true,
    );

    await _pumpDemo(tester, contentRepository);
    await _openCategories(tester);
    await _openDetail(tester);
    await _openLessonLastPage(tester);
    await _openQuiz(tester);

    for (var activity = 1; activity <= 12; activity += 1) {
      await _answerActivity(tester, activity);
      _expectNoFlutterException(tester, reason: 'actividad $activity');

      if (activity == 6 || activity == 9) {
        expect(tester.testTextInput.isVisible, isFalse);
      }

      await tester.tap(
        find.text(
          activity == 12 ? AppStrings.seeResult : AppStrings.nextActivity,
        ),
      );
      if (activity == 12) {
        await _pumpUntilFound(tester, find.text(AppStrings.lessonCompleted));
      } else {
        await _pumpRouteFrame(tester);
      }
      _expectNoFlutterException(
        tester,
        reason: 'después de avanzar desde actividad $activity',
      );
    }

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.repeatLesson), findsOneWidget);
    expect(find.text(AppStrings.backToCategories), findsOneWidget);
    _expectPrimaryButtonTarget(tester, AppStrings.repeatLesson);
  });
}

Future<void> _configureView(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
  tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
  tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.binding.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: disableAnimations);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}

Future<void> _pumpDemo(
  WidgetTester tester,
  ContentRepository contentRepository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    YoMeCuidoApp(key: UniqueKey(), contentRepository: contentRepository),
  );
  await _pumpRouteFrame(tester);
}

Future<void> _openCategories(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.start));
  await _pumpUntilFound(tester, find.text('Relaciones y violencia digital'));
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('Relaciones y violencia digital').first);
  await _pumpUntilFound(tester, find.text(AppStrings.startLesson));
}

Future<void> _openLessonLastPage(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.startLesson));
  await _pumpUntilFound(tester, find.text('1 de 4'));

  for (var index = 0; index < 3; index += 1) {
    await tester.tap(find.text(AppStrings.next));
    await _pumpRouteFrame(tester);
  }
}

Future<void> _openQuiz(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.startActivities));
  await _pumpUntilFound(tester, find.text(AppStrings.quizTitle));
}

Future<void> _answerActivity(WidgetTester tester, int activity) async {
  final textField = find.byType(TextField);
  if (textField.evaluate().isNotEmpty) {
    await tester.enterText(
      textField,
      activity == 6 ? 'sextorsion' : 'evidencia',
    );
  } else {
    final option = find.byType(AnswerOptionTile).first;
    await tester.ensureVisible(option);
    await tester.tap(option);
  }

  await _pumpRouteFrame(tester);
  await tester.tap(find.text(AppStrings.submitAnswer));
  await _pumpRouteFrame(tester);
}

void _expectPrimaryButtonTarget(WidgetTester tester, String label) {
  final button = find.widgetWithText(ElevatedButton, label);
  expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
}

void _expectNoFlutterException(WidgetTester tester, {String? reason}) {
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _pumpRouteFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await _pumpRouteFrame(tester);
      return;
    }
  }

  expect(finder, findsWidgets);
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

class _CachedContentRepository implements ContentRepository {
  const _CachedContentRepository({
    required this.categories,
    required this.lessonPages,
    required this.quizQuestions,
  });

  final List<Category> categories;
  final List<LessonPage> lessonPages;
  final List<QuizQuestion> quizQuestions;

  @override
  Future<List<Category>> loadCategories() async {
    return categories;
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    return lessonPages;
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId) async {
    return quizQuestions;
  }
}
