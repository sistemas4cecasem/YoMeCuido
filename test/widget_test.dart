import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/features/splash/welcome_screen.dart';
import 'package:demo_yomecuido/shared/widgets/answer_option_tile.dart';
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

  Future<void> openQuiz(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relaciones y violencia digital'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.startActivities));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.firstActivityBlock));
    await tester.tap(find.text(AppStrings.firstActivityBlock));
    await tester.pumpAndSettle();
  }

  Future<void> answerActivity(
    WidgetTester tester,
    int activity, {
    required bool correctly,
  }) async {
    if (activity == 2) {
      await tester.enterText(
        find.byType(TextField),
        correctly ? ' evidencia ' : 'otra',
      );
    } else {
      final option = correctly
          ? find.byType(AnswerOptionTile).first
          : find.byType(AnswerOptionTile).last;
      await tester.ensureVisible(option);
      await tester.tap(option);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.submitAnswer));
    await tester.pumpAndSettle();
  }

  Future<void> completeActivities(
    WidgetTester tester, {
    required int correctAnswers,
  }) async {
    for (var activity = 1; activity <= 12; activity += 1) {
      await answerActivity(
        tester,
        activity,
        correctly: activity <= correctAnswers,
      );

      final nextButton = find.text(
        activity == 12 ? AppStrings.seeResult : AppStrings.nextActivity,
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  Future<void> openCategories(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.start));
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await openCategories(tester);
    await tester.tap(find.text('Relaciones y violencia digital'));
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
    await openCategories(tester);

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
    await openCategories(tester);

    await tester.tap(find.text('Protección de cuentas y autenticación'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.theoryTitle), findsNothing);
    expect(find.text(AppStrings.categoriesTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoonSnackBar), findsOneWidget);
  });

  testWidgets('abre el detalle desde la categoría habilitada', (tester) async {
    await openDetail(tester);

    expect(find.text('Relaciones y violencia digital'), findsWidgets);
    expect(
      find.text(
        'Aprende a reconocer el control, el acoso, las amenazas y otras '
        'formas de violencia que pueden ocurrir mediante redes sociales, '
        'mensajería, cuentas y dispositivos.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el detalle muestra datos principales', (tester) async {
    await openDetail(tester);

    expect(find.byIcon(Icons.shield_outlined), findsWidgets);
    expect(find.text('12 actividades'), findsOneWidget);
    expect(find.text('10–15 minutos'), findsOneWidget);
    expect(find.text('Nivel básico e intermedio'), findsOneWidget);
    expect(find.byTooltip(AppStrings.viewObjectives), findsOneWidget);
    expect(find.text(AppStrings.objectivesTitle), findsNothing);
    expect(find.text(AppStrings.sensitiveContentWarningTitle), findsOneWidget);
    expect(find.text(AppStrings.theoryTitle), findsOneWidget);
    expect(find.text(AppStrings.activitiesTitle), findsOneWidget);
    expect(find.text(AppStrings.summaryTitle), findsWidgets);
  });

  testWidgets('el detalle muestra objetivos en una ventana flotante', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.tap(find.byTooltip(AppStrings.viewObjectives));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.objectivesTitle), findsOneWidget);
    expect(
      find.text('Identificar señales de control y acoso digital.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Comprender la importancia del consentimiento y de las redes de apoyo.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.close));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.objectivesTitle), findsNothing);
  });

  testWidgets('navega entre las cuatro cápsulas teóricas', (tester) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();

    expect(repository.loadLessonPagesCalls, 1);
    expect(find.text('1 de 4'), findsOneWidget);
    expect(find.text('¿Qué es la violencia digital?'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isFalse,
    );

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text('2 de 4'), findsOneWidget);
    expect(
      find.text('El control no es una muestra de cuidado'),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isTrue,
    );

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text('3 de 4'), findsOneWidget);
    expect(find.text('Consentimiento y contenido íntimo'), findsOneWidget);

    await tester.tap(find.text(AppStrings.previous));
    await tester.pumpAndSettle();
    expect(find.text('2 de 4'), findsOneWidget);

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text('4 de 4'), findsOneWidget);
    expect(find.text('Cómo actuar'), findsOneWidget);
    expect(find.text(AppStrings.startActivities), findsOneWidget);
    expect(find.text(AppStrings.next), findsNothing);
  });

  testWidgets('el último botón abre el menú de actividades y el cuestionario', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.startActivities));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.activitiesTitle), findsWidgets);
    expect(find.text(AppStrings.firstActivityBlock), findsOneWidget);
    expect(find.text(AppStrings.secondActivityBlock), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.firstActivityBlock));
    await tester.tap(find.text(AppStrings.firstActivityBlock));
    await tester.pumpAndSettle();

    expect(repository.loadQuizQuestionsCalls, 2);
    expect(find.text(AppStrings.quizTitle), findsOneWidget);
    expect(find.text('Actividad 1 de 12'), findsNothing);
    expect(
      find.text('¿Cuál es un ejemplo de violencia digital?'),
      findsOneWidget,
    );
  });

  testWidgets('volver desde actividades abre el detalle de categorÃ­a', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.startActivities));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.firstActivityBlock), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.learningRouteTitle), findsOneWidget);
    expect(find.text(AppStrings.startActivities), findsNothing);
  });

  testWidgets('repetir lecci\u00f3n vuelve a la primera actividad', (
    tester,
  ) async {
    await openQuiz(tester);
    await completeActivities(tester, correctAnswers: 12);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('12 de 12'), findsOneWidget);

    await tester.tap(find.text(AppStrings.repeatLesson));
    await tester.pumpAndSettle();

    expect(
      find.text('\u00bfCu\u00e1l es un ejemplo de violencia digital?'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.lessonCompleted), findsNothing);
    expect(find.text(AppStrings.quizTitle), findsOneWidget);
    expect(find.text(AppStrings.submitAnswer), findsNothing);
  });

  testWidgets('repetir lecci\u00f3n reinicia el puntaje', (tester) async {
    await openQuiz(tester);
    await completeActivities(tester, correctAnswers: 12);

    await tester.tap(find.text(AppStrings.repeatLesson));
    await tester.pumpAndSettle();

    await completeActivities(tester, correctAnswers: 0);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('0 de 12'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.text(
        'Has completado la lecci\u00f3n. Puedes repetirla y revisar nuevamente las recomendaciones.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el resultado no muestra volver a categor\u00edas', (
    tester,
  ) async {
    await openQuiz(tester);
    await completeActivities(tester, correctAnswers: 8);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text(AppStrings.backToCategories), findsNothing);
  });

  testWidgets('volver a actividades abre el listado de actividades', (
    tester,
  ) async {
    await openQuiz(tester);
    await completeActivities(tester, correctAnswers: 8);

    await tester.tap(find.text(AppStrings.backToActivities));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.lessonCompleted), findsNothing);
    expect(find.text(AppStrings.firstActivityBlock), findsOneWidget);
    expect(find.text(AppStrings.secondActivityBlock), findsOneWidget);
  });
}

class _FakeContentRepository implements ContentRepository {
  int loadCategoriesCalls = 0;
  int loadLessonPagesCalls = 0;
  int loadQuizQuestionsCalls = 0;

  final categories = const <Category>[
    Category(
      id: 'relations_violence_digital',
      title: 'Relaciones y violencia digital',
      description:
          'Aprende a reconocer el control, el acoso, las amenazas y otras '
          'formas de violencia que pueden ocurrir mediante redes sociales, '
          'mensajería, cuentas y dispositivos.',
      iconName: 'shield_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>[
        '12 actividades',
        '10–15 minutos',
        'Nivel básico e intermedio',
      ],
      objectives: <String>[
        'Identificar señales de control y acoso digital.',
        'Proteger la privacidad y recuperar el control de las cuentas.',
        'Reconocer acciones seguras ante amenazas.',
        'Comprender la importancia del consentimiento y de las redes de apoyo.',
      ],
      warning:
          'Algunos contenidos mencionan acoso, amenazas, grooming y difusión '
          'no consentida de contenido íntimo. Puedes salir de la lección '
          'cuando lo necesites.',
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

  final lessonPages = const <LessonPage>[
    LessonPage(
      id: 'what_is_digital_violence',
      order: 1,
      title: '¿Qué es la violencia digital?',
      body:
          'La violencia digital incluye acciones realizadas mediante redes '
          'sociales, mensajería, cuentas o dispositivos para controlar, '
          'vigilar, intimidar, acosar o causar daño a otra persona.',
    ),
    LessonPage(
      id: 'control_is_not_care',
      order: 2,
      title: 'El control no es una muestra de cuidado',
      body:
          'Exigir contraseñas, revisar mensajes sin permiso, controlar '
          'contactos o pedir la ubicación en todo momento puede ser una forma '
          'de control digital.',
    ),
    LessonPage(
      id: 'consent_and_intimate_content',
      order: 3,
      title: 'Consentimiento y contenido íntimo',
      body:
          'Compartir una imagen con una persona no significa autorizar su '
          'publicación o reenvío.',
    ),
    LessonPage(
      id: 'how_to_act',
      order: 4,
      title: 'Cómo actuar',
      body:
          'Ante amenazas o acoso, conviene guardar evidencia, proteger las '
          'cuentas, bloquear o reportar cuando sea seguro y buscar apoyo.',
    ),
  ];

  final quizQuestions = _buildQuizQuestions();

  @override
  Future<List<Category>> loadCategories() async {
    loadCategoriesCalls += 1;
    return categories;
  }

  @override
  Future<List<LessonPage>> loadLessonPages(String categoryId) async {
    loadLessonPagesCalls += 1;
    return lessonPages;
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(String categoryId) async {
    loadQuizQuestionsCalls += 1;
    return quizQuestions;
  }
}

List<QuizQuestion> _buildQuizQuestions() {
  return <QuizQuestion>[
    const QuizQuestion(
      id: 'activity_1',
      type: QuestionType.multipleChoice,
      statement: '¿Cuál es un ejemplo de violencia digital?',
      options: <QuizOption>[
        QuizOption(
          id: 'control_passwords_threaten_messages',
          text: 'Controlar contraseñas y amenazar por mensajes.',
        ),
        QuizOption(
          id: 'update_application',
          text: 'Actualizar una aplicación.',
        ),
      ],
      correctAnswer: 'control_passwords_threaten_messages',
      acceptedAnswers: <String>['control_passwords_threaten_messages'],
      feedback:
          'El control, la vigilancia y las amenazas mediante tecnología son '
          'formas de violencia.',
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
      feedback: 'Conviene almacenar las pruebas de manera segura.',
      capacity: 'responder',
      difficulty: 'básica',
    ),
    for (var index = 3; index <= 12; index += 1)
      QuizQuestion(
        id: 'activity_$index',
        type: QuestionType.multipleChoice,
        statement: 'Actividad de práctica $index',
        options: <QuizOption>[
          QuizOption(id: 'safe_action_$index', text: 'Acción segura $index.'),
          QuizOption(
            id: 'unsafe_action_$index',
            text: 'Acción insegura $index.',
          ),
        ],
        correctAnswer: 'safe_action_$index',
        acceptedAnswers: <String>['safe_action_$index'],
        feedback: 'Esta acción ayuda a proteger y buscar apoyo.',
        capacity: 'responder',
        difficulty: 'básica',
      ),
  ];
}
