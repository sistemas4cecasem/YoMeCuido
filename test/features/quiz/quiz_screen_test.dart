import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/quiz/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeQuizRepository repository;

  setUp(() {
    repository = _FakeQuizRepository();
  });

  Future<void> pumpQuiz(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => QuizScreen(
                      category: _category,
                      contentRepository: repository,
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

  Future<void> selectFirstOption(WidgetTester tester) async {
    await tester.tap(find.text('Respuesta correcta'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.submitAnswer));
    await tester.pumpAndSettle();
  }

  Future<void> answerCurrentCorrectly(WidgetTester tester, int activity) async {
    if (activity == 2) {
      await tester.enterText(find.byType(TextField), ' evidencia ');
      await tester.pumpAndSettle();
    } else {
      await tester.tap(find.text('Respuesta correcta'));
      await tester.pumpAndSettle();
    }

    await submit(tester);
  }

  testWidgets('botón Responder inicia deshabilitado sin selección', (
    tester,
  ) async {
    await pumpQuiz(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
    );

    expect(button.enabled, isFalse);
  });

  testWidgets(
    'la selección de opción distingue la tarjeta y habilita responder',
    (tester) async {
      await pumpQuiz(tester);

      await selectFirstOption(tester);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
      );
      expect(button.enabled, isTrue);
    },
  );

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

  testWidgets('muestra retroalimentación respetuosa con respuesta esperada', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await tester.tap(find.text('Respuesta incorrecta'));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(find.text(AppStrings.reviewAnswer), findsOneWidget);
    expect(find.text('Retroalimentación exacta.'), findsOneWidget);
    expect(
      find.text('${AppStrings.expectedAnswer}: Respuesta correcta'),
      findsOneWidget,
    );
  });

  testWidgets('avanza de actividad después de la retroalimentación', (
    tester,
  ) async {
    await pumpQuiz(tester);

    await selectFirstOption(tester);
    await submit(tester);
    await tester.tap(find.text(AppStrings.nextActivity));
    await tester.pumpAndSettle();

    expect(find.text('Actividad 2 de 12'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('permite completar una palabra breve', (tester) async {
    await pumpQuiz(tester);

    await answerCurrentCorrectly(tester, 1);
    await tester.tap(find.text(AppStrings.nextActivity));
    await tester.pumpAndSettle();

    final buttonBeforeInput = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, AppStrings.submitAnswer),
    );
    expect(buttonBeforeInput.enabled, isFalse);

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
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exitLessonTitle), findsOneWidget);
    expect(find.text(AppStrings.exitLessonBody), findsOneWidget);

    await tester.tap(find.text(AppStrings.keepLearning));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exitLessonTitle), findsNothing);
    expect(find.text('Actividad 1 de 12'), findsOneWidget);
  });

  testWidgets('llega al resultado después de 12 actividades', (tester) async {
    await pumpQuiz(tester);

    for (var activity = 1; activity <= 12; activity += 1) {
      await answerCurrentCorrectly(tester, activity);

      if (activity < 12) {
        await tester.tap(find.text(AppStrings.nextActivity));
      } else {
        await tester.tap(find.text(AppStrings.seeResult));
      }
      await tester.pumpAndSettle();
    }

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('12 de 12 respuestas correctas'), findsOneWidget);
    expect(find.text(AppStrings.repeatLesson), findsOneWidget);
    expect(find.text(AppStrings.backToCategories), findsOneWidget);
  });
}

class _FakeQuizRepository implements ContentRepository {
  @override
  Future<List<Category>> loadCategories() {
    throw UnimplementedError();
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId) async {
    return _quizQuestions;
  }
}

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

List<QuizQuestion> get _quizQuestions {
  return <QuizQuestion>[
    const QuizQuestion(
      id: 'activity_1',
      type: QuestionType.multipleChoice,
      statement: 'Pregunta de opción múltiple',
      options: <QuizOption>[
        QuizOption(id: 'correct', text: 'Respuesta correcta'),
        QuizOption(id: 'incorrect', text: 'Respuesta incorrecta'),
      ],
      correctAnswer: 'correct',
      acceptedAnswers: <String>['correct'],
      feedback: 'Retroalimentación exacta.',
      capacity: 'reconocer',
      difficulty: 'básica',
    ),
    const QuizQuestion(
      id: 'activity_2',
      type: QuestionType.fillBlank,
      statement: 'Las capturas pueden servir como ______.',
      options: <QuizOption>[],
      correctAnswer: 'evidencia',
      acceptedAnswers: <String>['evidencia'],
      feedback: 'La palabra se valida sin depender de mayúsculas.',
      capacity: 'responder',
      difficulty: 'básica',
    ),
    for (var index = 3; index <= 12; index += 1)
      QuizQuestion(
        id: 'activity_$index',
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
