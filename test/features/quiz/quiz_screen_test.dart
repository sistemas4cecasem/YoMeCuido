import 'dart:math' as math;

import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/quiz/exam_question_selector.dart';
import 'package:demo_yomecuido/features/quiz/quiz_screen.dart';
import 'package:demo_yomecuido/shared/widgets/character_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeQuizRepository repository;
  late CategoryProgressController progressController;

  setUp(() {
    repository = _FakeQuizRepository();
    progressController = CategoryProgressController(
      attemptIdGenerator: _sequentialAttemptIds(),
    );
  });

  Future<void> pumpQuiz(
    WidgetTester tester, {
    LearningActivity activity = _activity,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => QuizScreen.activity(
                      category: _category,
                      activity: activity,
                      contentRepository: repository,
                      progressController: progressController,
                      shuffleQuestions: false,
                      shuffleOptions: false,
                    ),
                  ),
                );
              },
              child: const Text('Abrir cuestionario'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir cuestionario'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpExam(
    WidgetTester tester, {
    ExamQuestionSelector? selector,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: QuizScreen.exam(
          category: _category,
          exam: FinalExamConfigs.relationsViolence,
          contentRepository: repository,
          progressController: progressController,
          examQuestionSelector: selector,
          shuffleQuestions: false,
          shuffleOptions: false,
          totalActivities: 6,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> selectFirstOption(WidgetTester tester) async {
    final option = find.text('Respuesta correcta');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.submitAnswer));
    await tester.pumpAndSettle();
  }

  Future<void> answerCurrentCorrectly(WidgetTester tester, int activity) async {
    if (find.byType(TextField).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField), ' evidencia ');
      await tester.pumpAndSettle();
    } else {
      final option = find.text('Respuesta correcta');
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    await submit(tester);
  }

  Future<void> answerCurrentIncorrectly(WidgetTester tester) async {
    if (find.byType(TextField).evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField), 'respuesta');
      await tester.pumpAndSettle();
    } else {
      final option = find.text('Respuesta incorrecta').first;
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    await submit(tester);
  }

  Future<void> completeQuiz(WidgetTester tester) async {
    for (var activity = 1; activity <= 10; activity += 1) {
      await answerCurrentCorrectly(tester, activity);

      if (activity < 10) {
        await tester.tap(find.text(AppStrings.nextActivity));
      } else {
        await tester.tap(find.text(AppStrings.seeResult));
      }
      await tester.pumpAndSettle();
    }
  }

  Future<void> completeQuizWithCorrectAnswers(
    WidgetTester tester, {
    required int correctAnswers,
    int totalQuestions = 10,
  }) async {
    for (var question = 1; question <= totalQuestions; question += 1) {
      if (question <= correctAnswers) {
        await answerCurrentCorrectly(tester, question);
      } else {
        await answerCurrentIncorrectly(tester);
      }

      await tester.tap(
        find.text(
          question == totalQuestions
              ? AppStrings.seeResult
              : AppStrings.nextActivity,
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> completeVisibleQuiz(
    WidgetTester tester, {
    required int totalQuestions,
  }) async {
    for (var question = 1; question <= totalQuestions; question += 1) {
      await answerCurrentCorrectly(tester, question);

      await tester.tap(
        find.text(
          question == totalQuestions
              ? AppStrings.seeResult
              : AppStrings.nextActivity,
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('botón Responder no se muestra sin selección', (tester) async {
    await pumpQuiz(tester);

    expect(progressController.attemptFor('attempt_1'), isNull);
    expect(find.text(AppStrings.submitAnswer), findsNothing);
    expect(find.text('Pregunta 1 de 10'), findsNothing);
  });

  testWidgets('muestra el total real con diez preguntas', (tester) async {
    repository.quizQuestions = _buildQuizQuestions(10);

    await pumpQuiz(tester);

    expect(find.text('Pregunta 1 de 10'), findsNothing);

    for (var activity = 1; activity < 10; activity += 1) {
      await answerCurrentCorrectly(tester, activity);
      await tester.tap(find.text(AppStrings.nextActivity));
      await tester.pumpAndSettle();
    }

    expect(find.text('Pregunta 10 de 10'), findsNothing);

    await answerCurrentCorrectly(tester, 10);
    await tester.tap(find.text(AppStrings.seeResult));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('10 de 10 correctas'), findsOneWidget);
  });

  testWidgets('muestra error de carga para una lista vacía', (tester) async {
    repository.quizQuestions = const <QuizQuestion>[];

    await pumpQuiz(tester);

    expect(find.text(AppStrings.contentLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text('Pregunta 1 de 0'), findsNothing);
  });

  testWidgets(
    'muestra estado insuficiente si el examen no tiene 15 preguntas',
    (tester) async {
      repository.quizQuestions = _buildQuizQuestions(12);

      await pumpExam(tester);

      expect(
        find.text(
          'El banco actual tiene 12 preguntas. '
          'El examen final necesita 15 para iniciar.',
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.text('Pregunta 1 de 15'), findsNothing);
    },
  );

  testWidgets('inicia examen final con 15 preguntas seleccionadas', (
    tester,
  ) async {
    repository.quizQuestions = _buildQuizQuestions(18);

    await pumpExam(tester);

    expect(find.text('Pregunta 1 de 15'), findsNothing);

    final examProgress = progressController.examProgressFor(
      categoryId: _category.id,
      examId: FinalExamConfigs.relationsViolence.id,
    );
    expect(examProgress.status, ActivityProgressStatus.notStarted);
    expect(examProgress.attemptCount, 0);
  });

  testWidgets('repetir examen crea nuevo intento con nueva selección', (
    tester,
  ) async {
    repository.quizQuestions = _buildMultipleChoiceQuestions(30);
    final selector = ExamQuestionSelector(random: math.Random(8));

    await pumpExam(tester, selector: selector);
    expect(progressController.attemptFor('attempt_1'), isNull);

    await completeVisibleQuiz(tester, totalQuestions: 15);
    final firstAttempt = progressController.attemptFor('attempt_1');
    await tester.tap(find.text(AppStrings.repeatLesson));
    await tester.pumpAndSettle();
    expect(progressController.attemptFor('attempt_2'), isNull);
    await completeVisibleQuiz(tester, totalQuestions: 15);

    final secondAttempt = progressController.attemptFor('attempt_2');

    expect(firstAttempt?.questionIds, hasLength(15));
    expect(secondAttempt?.questionIds, hasLength(15));
    expect(secondAttempt?.id, isNot(firstAttempt?.id));
    expect(secondAttempt?.questionIds, isNot(firstAttempt?.questionIds));
    expect(find.text('Pregunta 1 de 15'), findsNothing);
  });

  testWidgets(
    'la selección de opción distingue la tarjeta y habilita responder',
    (tester) async {
      await pumpQuiz(tester);

      await selectFirstOption(tester);

      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
      );
      expect(button.enabled, isTrue);
    },
  );

  testWidgets('tocar otra vez una opción la desmarca', (tester) async {
    await pumpQuiz(tester);

    final option = find.text('Respuesta correcta');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.submitAnswer), findsOneWidget);

    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.submitAnswer), findsNothing);
  });

  testWidgets('confirma respuesta y muestra retroalimentación correcta', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await selectFirstOption(tester);
    await submit(tester);

    expect(find.text(AppStrings.correct), findsOneWidget);
    expect(find.text('Retroalimentación exacta.'), findsOneWidget);
    expect(find.text(AppStrings.submitAnswer), findsNothing);
    expect(find.text(AppStrings.nextActivity), findsOneWidget);
  });

  testWidgets('marca la opción correcta al responder incorrectamente', (
    tester,
  ) async {
    await pumpQuiz(tester);

    final incorrectOption = find.text('Respuesta incorrecta');
    await tester.ensureVisible(incorrectOption);
    await tester.tap(incorrectOption);
    await tester.pumpAndSettle();
    await submit(tester);

    expect(find.text(AppStrings.reviewAnswer), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
    expect(find.text('Retroalimentación exacta.'), findsOneWidget);
    expect(
      find.text('${AppStrings.expectedAnswer}: Respuesta correcta'),
      findsNothing,
    );
    expect(find.text('Respuesta incorrecta'), findsOneWidget);
    expect(find.text('Respuesta correcta'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);

    final incorrectTop = tester.getTopLeft(find.text('Respuesta incorrecta'));
    final correctTop = tester.getTopLeft(find.text('Respuesta correcta'));
    expect(incorrectTop.dy, lessThan(correctTop.dy));
  });

  testWidgets('muestra solo la palabra correcta si se equivoca en completar', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await answerCurrentCorrectly(tester, 1);
    await tester.tap(find.text(AppStrings.nextActivity));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'evide');
    await tester.pumpAndSettle();
    await submit(tester);

    expect(find.text(AppStrings.reviewAnswer), findsOneWidget);
    expect(
      find.text('${AppStrings.expectedAnswer}: evidencia'),
      findsOneWidget,
    );
    expect(find.textContaining('evidencia,'), findsNothing);
  });

  testWidgets('avanza de actividad después de la retroalimentación', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await selectFirstOption(tester);
    await submit(tester);
    await tester.tap(find.text(AppStrings.nextActivity));
    await tester.pumpAndSettle();

    expect(find.text('Actividad 2 de 12'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('permite completar una palabra breve', (tester) async {
    await pumpQuiz(tester);

    await answerCurrentCorrectly(tester, 1);
    await tester.tap(find.text(AppStrings.nextActivity));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.submitAnswer), findsNothing);

    await tester.enterText(find.byType(TextField), ' evidencia ');
    await tester.pumpAndSettle();

    final buttonAfterInput = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
    );
    expect(buttonAfterInput.enabled, isTrue);

    await submit(tester);

    expect(find.text(AppStrings.correct), findsOneWidget);
    expect(
      find.text('La palabra se valida sin depender de mayúsculas.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra diálogo al intentar salir con progreso', (tester) async {
    await pumpQuiz(tester);

    await selectFirstOption(tester);
    await submit(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exitLessonTitle), findsOneWidget);
    expect(find.text(AppStrings.exitLessonBody), findsOneWidget);

    await tester.tap(find.text(AppStrings.keepLearning));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exitLessonTitle), findsNothing);
    expect(find.text('Actividad 1 de 12'), findsNothing);
  });

  testWidgets('llega al resultado después de 10 preguntas', (tester) async {
    await pumpQuiz(tester);

    await completeQuiz(tester);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('10 de 10 correctas'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('preguntas'), findsNothing);
    expect(find.text('correctas'), findsNothing);
    expect(find.text('por reforzar'), findsNothing);
    expect(
      find.text(
        'Muy bien. Reconoces varias señales de riesgo y acciones de protección.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CharacterImage), findsOneWidget);
    expect(find.text(AppStrings.backToActivities), findsOneWidget);
    expect(find.text(AppStrings.viewCategorySummary), findsNothing);
    expect(find.text(AppStrings.repeatLesson), findsOneWidget);
    expect(find.text(AppStrings.backToCategories), findsNothing);
  });

  testWidgets(
    'resultado medio muestra resumen compacto sin métricas duplicadas',
    (tester) async {
      progressController.hydrateTotalPointsFromProfile(
        uid: 'uid-123',
        totalPoints: 260,
      );
      await pumpQuiz(tester);

      await completeQuizWithCorrectAnswers(tester, correctAnswers: 6);

      expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('6 de 10 correctas'), findsOneWidget);
      expect(
        find.text(
          'Buen trabajo. Sigue practicando para fortalecer tus decisiones de autocuidado.',
        ),
        findsOneWidget,
      );
      expect(find.text('+60'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);
      expect(find.text(AppStrings.takeawaysTitle), findsOneWidget);
      expect(find.text('Aprendizaje 1'), findsOneWidget);
      expect(find.text('preguntas'), findsNothing);
      expect(find.text('por reforzar'), findsNothing);
      expect(find.byType(CharacterImage), findsOneWidget);
    },
  );

  testWidgets('resultado bajo conserva estado y mensaje correspondiente', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await completeQuizWithCorrectAnswers(tester, correctAnswers: 5);

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('5 de 10 correctas'), findsOneWidget);
    expect(find.text('Necesita refuerzo'), findsOneWidget);
    expect(
      find.text(
        'Has completado la lección. Puedes repetirla y revisar nuevamente las recomendaciones.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CharacterImage), findsOneWidget);
  });

  testWidgets('muestra takeaways específicos de la actividad en resultado', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await completeQuiz(tester);

    expect(find.text(AppStrings.takeawaysTitle), findsOneWidget);
    expect(find.text('Recuerda'), findsNothing);
    expect(find.text('Aprendizaje 1'), findsOneWidget);
    expect(find.text('Aprendizaje 2'), findsOneWidget);
    expect(find.text('Aprendizaje 3'), findsOneWidget);
    expect(find.text('Protege tus cuentas y revisa accesos.'), findsNothing);
    expect(find.text('Guarda evidencia ante amenazas o acoso.'), findsNothing);
    expect(find.text('Busca apoyo y prioriza tu seguridad.'), findsNothing);
  });

  testWidgets('oculta cierre pedagógico si la actividad no tiene takeaways', (
    tester,
  ) async {
    await pumpQuiz(tester, activity: _legacyActivity);

    await completeQuiz(tester);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.takeawaysTitle), findsNothing);
    expect(find.text('Recuerda'), findsNothing);
    expect(find.text('Protege tus cuentas y revisa accesos.'), findsNothing);
    expect(find.text('Guarda evidencia ante amenazas o acoso.'), findsNothing);
    expect(find.text('Busca apoyo y prioriza tu seguridad.'), findsNothing);
  });

  testWidgets('actividades distintas muestran takeaways distintos', (
    tester,
  ) async {
    repository.quizQuestions = _buildQuizQuestions(
      10,
      activityId: _secondActivity.id,
    );

    await pumpQuiz(tester, activity: _secondActivity);
    await completeQuiz(tester);

    expect(find.text(AppStrings.takeawaysTitle), findsOneWidget);
    expect(find.text('Segundo aprendizaje 1'), findsOneWidget);
    expect(find.text('Segundo aprendizaje 2'), findsOneWidget);
    expect(find.text('Segundo aprendizaje 3'), findsOneWidget);
    expect(find.text('Aprendizaje 1'), findsNothing);
  });

  testWidgets('el resultado de examen no muestra cierre pedagógico', (
    tester,
  ) async {
    repository.quizQuestions = _buildMultipleChoiceQuestions(18);

    await pumpExam(tester);
    await completeVisibleQuiz(tester, totalQuestions: 15);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.takeawaysTitle), findsNothing);
    expect(find.text('Recuerda'), findsNothing);
    expect(find.text('Protege tus cuentas y revisa accesos.'), findsNothing);
    expect(find.text('Guarda evidencia ante amenazas o acoso.'), findsNothing);
    expect(find.text('Busca apoyo y prioriza tu seguridad.'), findsNothing);
  });

  testWidgets('muestra puntos del intento separados del total personal', (
    tester,
  ) async {
    progressController.hydrateTotalPointsFromProfile(
      uid: 'uid-123',
      totalPoints: 830,
    );
    await pumpQuiz(tester);

    await completeQuiz(tester);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.earnedPoints.toLowerCase()), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(find.text(AppStrings.totalPoints.toLowerCase()), findsOneWidget);
    expect(find.text('930'), findsOneWidget);
  });

  testWidgets('el resultado final bloquea volver atrás', (tester) async {
    await pumpQuiz(tester);
    await completeQuiz(tester);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.exitLessonTitle), findsNothing);
  });

  testWidgets(
    'enviar una palabra desde el teclado mantiene actividad abierta',
    (tester) async {
      await pumpQuiz(tester);

      await answerCurrentCorrectly(tester, 1);
      await tester.tap(find.text(AppStrings.nextActivity));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), ' evidencia ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final progress = progressController.snapshotFor(_category.id);
      final activityProgress = progressController.activityProgressFor(
        categoryId: _category.id,
        activityId: _activity.id,
      );
      expect(find.text(AppStrings.correct), findsOneWidget);
      expect(progress.completedActivities, 0);
      expect(progress.completedActivityIds, isEmpty);
      expect(activityProgress.attemptCount, 0);
      expect(activityProgress.status, ActivityProgressStatus.notStarted);
    },
  );
}

class _FakeQuizRepository implements ContentRepository {
  List<QuizQuestion> quizQuestions = _buildQuizQuestions(60);

  @override
  Future<List<Category>> loadCategories() {
    throw UnimplementedError();
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<LearningActivity>> loadActivities(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    return quizQuestions;
  }

  @override
  Future<FinalExamConfig?> loadFinalExamConfig(String categoryId) async {
    return FinalExamConfigs.forCategory(categoryId);
  }
}

const _activity = LearningActivity(
  id: 'relations_violence_activity_01',
  categoryId: 'relations_violence_digital',
  title: 'Actividad 1',
  order: 1,
  completion: ActivityCompletion(
    takeaways: <String>['Aprendizaje 1', 'Aprendizaje 2', 'Aprendizaje 3'],
  ),
);

const _legacyActivity = LearningActivity(
  id: 'relations_violence_activity_01',
  categoryId: 'relations_violence_digital',
  title: 'Actividad 1',
  order: 1,
);

const _secondActivity = LearningActivity(
  id: 'relations_violence_activity_02',
  categoryId: 'relations_violence_digital',
  title: 'Actividad 2',
  order: 2,
  completion: ActivityCompletion(
    takeaways: <String>[
      'Segundo aprendizaje 1',
      'Segundo aprendizaje 2',
      'Segundo aprendizaje 3',
    ],
  ),
);

const _category = Category(
  id: 'relations_violence_digital',
  title: 'Relaciones y violencia digital',
  description: 'Descripción',
  iconName: 'shield_outlined',
  status: CategoryStatus.available,
  isEnabled: true,
  indicators: <String>[],
  objectives: <String>[],
);

List<QuizQuestion> _buildQuizQuestions(
  int count, {
  String activityId = 'relations_violence_activity_01',
}) {
  return <QuizQuestion>[
    if (count >= 1)
      QuizQuestion(
        id: 'activity_1',
        categoryId: 'relations_violence_digital',
        activityId: activityId,
        type: QuestionType.multipleChoice,
        statement: 'Pregunta de opción múltiple',
        options: const <QuizOption>[
          QuizOption(id: 'correct', text: 'Respuesta correcta'),
          QuizOption(id: 'incorrect', text: 'Respuesta incorrecta'),
        ],
        correctAnswer: 'correct',
        acceptedAnswers: const <String>['correct'],
        feedback: 'Retroalimentación exacta.',
        capacity: 'reconocer',
        difficulty: 'básica',
      ),
    if (count >= 2)
      QuizQuestion(
        id: 'activity_2',
        categoryId: 'relations_violence_digital',
        activityId: activityId,
        type: QuestionType.fillBlank,
        statement: 'Las capturas pueden servir como ______.',
        options: const <QuizOption>[],
        correctAnswer: 'evidencia',
        acceptedAnswers: const <String>['evidencia'],
        feedback: 'La palabra se valida sin depender de mayúsculas.',
        capacity: 'responder',
        difficulty: 'básica',
      ),
    for (var index = 3; index <= count; index += 1)
      QuizQuestion(
        id: 'activity_$index',
        categoryId: 'relations_violence_digital',
        activityId: activityId,
        type: QuestionType.multipleChoice,
        statement: 'Pregunta $index',
        options: <QuizOption>[
          QuizOption(id: 'correct_$index', text: 'Respuesta correcta'),
          QuizOption(id: 'incorrect_$index', text: 'Respuesta incorrecta'),
        ],
        correctAnswer: 'correct_$index',
        acceptedAnswers: <String>['correct_$index'],
        feedback: 'Retroalimentación exacta.',
        capacity: 'responder',
        difficulty: 'básica',
      ),
  ];
}

List<QuizQuestion> _buildMultipleChoiceQuestions(int count) {
  return <QuizQuestion>[
    for (var index = 1; index <= count; index += 1)
      QuizQuestion(
        id: 'exam_question_$index',
        categoryId: 'relations_violence_digital',
        activityId: _examActivityIdForIndex(index),
        type: QuestionType.multipleChoice,
        statement: 'Pregunta de examen $index',
        options: <QuizOption>[
          QuizOption(id: 'correct_$index', text: 'Respuesta correcta'),
          QuizOption(id: 'incorrect_$index', text: 'Respuesta incorrecta'),
        ],
        correctAnswer: 'correct_$index',
        acceptedAnswers: <String>['correct_$index'],
        feedback: 'Retroalimentación exacta.',
        capacity: switch (index % 3) {
          0 => 'prevenir',
          1 => 'reconocer',
          _ => 'responder',
        },
        difficulty: index.isEven ? 'intermedia' : 'básica',
      ),
  ];
}

String _examActivityIdForIndex(int index) {
  final activityNumber = (((index - 1) % 6) + 1).toString().padLeft(2, '0');
  return 'relations_violence_activity_$activityNumber';
}

AttemptIdGenerator _sequentialAttemptIds() {
  var count = 0;
  return () {
    count += 1;
    return 'attempt_$count';
  };
}
