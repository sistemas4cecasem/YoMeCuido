import 'dart:convert';
import 'dart:io';

import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/core/theme/app_colors.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/shared/widgets/answer_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository contentRepository;

  setUpAll(() async {
    final categories = await _loadSeedList(
      'tool/seed/content/categories.json',
      'categories',
      Category.fromJson,
    );
    final lessonPages = await _loadSeedList(
      'tool/seed/content/relations_violence_lesson.json',
      'lessonPages',
      LessonPage.fromJson,
    );
    final activities = await _loadSeedList(
      'tool/seed/content/relations_violence_activities.json',
      'activities',
      LearningActivity.fromJson,
    );
    final quizQuestions = await _loadSeedList(
      'tool/seed/content/relations_violence_questions.json',
      'questions',
      QuizQuestion.fromJson,
    );

    contentRepository = _CachedContentRepository(
      categories: categories,
      lessonPages: lessonPages,
      activities: activities,
      quizQuestions: quizQuestions,
      examConfig: FinalExamConfigs.relationsViolence,
    );
  });

  const sizes = <Size>[Size(360, 640), Size(393, 873), Size(412, 915)];

  test('la identidad visual fija mantiene contrastes principales', () {
    const colors = AppColors.fixed;

    expect(_contrast(colors.textPrimary, colors.background), greaterThan(7));
    expect(_contrast(colors.textSecondary, colors.surface), greaterThan(4.5));
    expect(_contrast(colors.textPrimary, colors.orangeSoft), greaterThan(4.5));
    expect(_contrast(colors.orangeDark, colors.orangeSoft), greaterThan(3));
    expect(_contrast(colors.error, colors.surface), greaterThan(4.5));
    expect(_contrast(colors.success, colors.surface), greaterThan(4.5));
    expect(colors.orangePrimary, isNot(colors.purpleSecondary));
  });

  for (final size in sizes) {
    testWidgets('flujo principal sin overflow en ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      await _configureView(tester, size: size);

      await _pumpDemo(tester, contentRepository);
      _expectNoFlutterException(tester);
      _expectRouteStepTarget(tester, AppStrings.digitalSecurityTitle);

      await _openCategories(tester);
      _expectNoFlutterException(tester);
      expect(find.text(AppStrings.comingSoon), findsAtLeastNWidgets(7));
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      await _openDetail(tester);
      _expectNoFlutterException(tester);
      _expectRouteStepTarget(tester, AppStrings.activitiesTitle);

      await _openLessonLastPage(tester);
      _expectNoFlutterException(tester);
      _expectPrimaryButtonTarget(tester, AppStrings.startActivities);

      await _openQuiz(tester);
      _expectNoFlutterException(tester);
      expect(find.text(AppStrings.submitAnswer), findsNothing);

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
      textScale: 1.6,
      disableAnimations: true,
    );

    await _pumpDemo(tester, contentRepository);
    await _openCategories(tester);
    await _openDetail(tester);
    _expectNoFlutterException(tester, reason: 'detalle con texto escalado');
    await _openLessonLastPage(tester);
    _expectNoFlutterException(tester, reason: 'teoría con texto escalado');
    await _openQuiz(tester);
    _expectNoFlutterException(tester, reason: 'quiz con texto escalado');

    for (var question = 1; question <= 10; question += 1) {
      await _answerActivity(tester, question);
      _expectNoFlutterException(tester, reason: 'pregunta $question');

      if (question == 6 || question == 9) {
        expect(tester.testTextInput.isVisible, isFalse);
      }

      final nextButton = find.text(
        question == 10 ? AppStrings.seeResult : AppStrings.nextActivity,
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      if (question == 10) {
        await _pumpUntilFound(tester, find.text(AppStrings.lessonCompleted));
      } else {
        await _pumpRouteFrame(tester);
      }
      _expectNoFlutterException(
        tester,
        reason: 'después de avanzar desde pregunta $question',
      );
    }

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.repeatLesson), findsOneWidget);
    expect(find.text(AppStrings.backToCategories), findsNothing);
    _expectPrimaryButtonTarget(tester, AppStrings.backToActivities);
  });
}

Future<void> _configureView(
  WidgetTester tester, {
  required Size size,
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
    YoMeCuidoApp(
      key: UniqueKey(),
      contentRepository: contentRepository,
      authRepository: const _SignedInAuthRepository(),
      progressController: CategoryProgressController(),
    ),
  );
  await _pumpRouteFrame(tester);
}

Future<void> _openCategories(WidgetTester tester) async {
  final digitalSecurityCardTitle = find
      .text(AppStrings.digitalSecurityTitle)
      .last;
  await tester.ensureVisible(digitalSecurityCardTitle);
  await _pumpRouteFrame(tester);
  await tester.tap(digitalSecurityCardTitle);
  await _pumpUntilFound(tester, find.text('Relaciones y violencia digital'));
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('Relaciones y violencia digital').first);
  await _pumpUntilFound(tester, find.text(AppStrings.theoryTitle));
}

Future<void> _openLessonLastPage(WidgetTester tester) async {
  await tester.ensureVisible(find.text(AppStrings.theoryTitle));
  await tester.tap(find.text(AppStrings.theoryTitle));
  await _pumpUntilFound(tester, find.text('1 de 6'));

  for (var index = 0; index < 5; index += 1) {
    await tester.tap(find.text(AppStrings.next));
    await _pumpRouteFrame(tester);
  }
}

Future<void> _openQuiz(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.startActivities));
  const firstActivityTitle = 'Control, privacidad y límites digitales';
  await _pumpUntilFound(tester, find.text(firstActivityTitle));
  await tester.ensureVisible(find.text(firstActivityTitle));
  await tester.tap(find.text(firstActivityTitle));
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

void _expectRouteStepTarget(WidgetTester tester, String label) {
  final routeStepCard = find
      .ancestor(of: find.text(label), matching: find.byType(Card))
      .first;
  expect(tester.getSize(routeStepCard).height, greaterThanOrEqualTo(48));
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
  final higher = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final lower = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;

  return (higher + 0.05) / (lower + 0.05);
}

Future<List<T>> _loadSeedList<T>(
  String path,
  String listKey,
  T Function(Map<String, Object?> json) parser,
) async {
  final decoded = jsonDecode(await File(path).readAsString());
  if (decoded is List<Object?>) {
    return decoded
        .map((item) => parser(item as Map<String, Object?>))
        .toList(growable: false);
  }
  final root = decoded as Map<String, Object?>;
  final list = root[listKey] as List<Object?>;
  return list
      .map((item) => parser(item as Map<String, Object?>))
      .toList(growable: false);
}

class _CachedContentRepository implements ContentRepository {
  const _CachedContentRepository({
    required this.categories,
    required this.lessonPages,
    required this.activities,
    required this.quizQuestions,
    required this.examConfig,
  });

  final List<Category> categories;
  final List<LessonPage> lessonPages;
  final List<LearningActivity> activities;
  final List<QuizQuestion> quizQuestions;
  final FinalExamConfig? examConfig;

  @override
  Future<List<Category>> loadCategories() async {
    return categories;
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    return lessonPages;
  }

  @override
  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    return activities;
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    return quizQuestions
        .where((question) {
          return question.categoryId == categoryId &&
              (activityId == null || question.activityId == activityId);
        })
        .toList(growable: false);
  }

  @override
  Future<FinalExamConfig?> loadFinalExamConfig(String categoryId) async {
    return examConfig?.categoryId == categoryId ? examConfig : null;
  }
}

class _SignedInAuthRepository implements AuthRepository {
  const _SignedInAuthRepository();

  static const _user = AuthUser(
    uid: 'uid-123',
    email: 'persona@example.com',
    isEmailVerified: true,
  );

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => _user;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
