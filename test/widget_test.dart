import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeContentRepository repository;

  setUp(() {
    repository = _FakeContentRepository();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    CategoryProgressController? progressController,
  }) async {
    await tester.pumpWidget(
      YoMeCuidoApp(
        contentRepository: repository,
        authRepository: const _SignedInAuthRepository(),
        progressController: progressController ?? CategoryProgressController(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> advanceTheoryToActivities(WidgetTester tester) async {
    while (find.text(AppStrings.startActivities).evaluate().isEmpty) {
      await tester.ensureVisible(find.text(AppStrings.next));
      await tester.tap(find.text(AppStrings.next));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(AppStrings.startActivities));
    await tester.pumpAndSettle();
  }

  Future<void> openQuiz(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relaciones y violencia digital'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await advanceTheoryToActivities(tester);
    await tester.ensureVisible(find.text(AppStrings.firstActivityBlock));
    await tester.tap(find.text(AppStrings.firstActivityBlock));
    await tester.pumpAndSettle();
  }

  Future<void> answerActivity(
    WidgetTester tester,
    int activity, {
    required bool correctly,
  }) async {
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField, correctly ? ' evidencia ' : 'otra');
    } else {
      final option = correctly
          ? _firstVisibleText(tester, <Finder>[
              find.text('Controlar contraseñas y amenazar por mensajes.'),
              find.textContaining('Acción segura'),
            ])
          : _firstVisibleText(tester, <Finder>[
              find.text('Actualizar una aplicación.'),
              find.textContaining('Acción insegura'),
            ]);
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
    await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await openCategories(tester);
    await tester.tap(find.text('Relaciones y violencia digital'));
    await tester.pumpAndSettle();
  }

  testWidgets('con sesión inicia en categorías altas', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('welcome_logo')), findsNothing);
    expect(find.text(AppStrings.start), findsNothing);
    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
  });

  testWidgets('las categorías altas no cargan categorías inferiores al abrir', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text(AppStrings.categoriesTitle), findsNothing);
    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoon), findsOneWidget);
    expect(repository.loadCategoriesCalls, 0);
  });

  testWidgets('trata y tráfico queda bloqueada', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(AppStrings.traffickingTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.categoriesTitle), findsNothing);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(find.text(AppStrings.comingSoonSnackBar), findsOneWidget);
    expect(repository.loadCategoriesCalls, 0);
  });

  testWidgets('seguridad digital abre las categorías existentes', (
    tester,
  ) async {
    await openCategories(tester);

    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(repository.loadCategoriesCalls, 1);
    expect(find.text('Relaciones y violencia digital'), findsOneWidget);
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
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
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
    expect(find.text('6 actividades'), findsOneWidget);
    expect(find.text('12 actividades'), findsNothing);
    expect(find.text('10–15 minutos'), findsOneWidget);
    expect(find.text('Nivel básico e intermedio'), findsOneWidget);
    expect(find.byTooltip(AppStrings.viewObjectives), findsOneWidget);
    expect(find.text(AppStrings.objectivesTitle), findsNothing);
    expect(find.text(AppStrings.sensitiveContentWarningTitle), findsOneWidget);
    expect(find.text(AppStrings.theoryTitle), findsOneWidget);
    expect(find.text(AppStrings.activitiesTitle), findsOneWidget);
    expect(find.text(AppStrings.summaryTitle), findsWidgets);
  });

  testWidgets('el detalle corrige totales antiguos con contenido real', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    final now = DateTime.utc(2026, 8, 31, 12);
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        CategoryProgressRecord(
          categoryId: 'relations_violence_digital',
          lessonId: 'relations_violence',
          status: CategoryProgressStatus.inProgress,
          viewedLessonPageIds: const <String>[
            'what_is_digital_violence',
            'control_is_not_care',
            'consent_and_intimate_content',
            'how_to_act',
          ],
          completedActivityIds: const <String>[],
          totalLessonPages: 4,
          totalActivities: 12,
          startedAt: now,
          lastActivityAt: null,
          completedAt: null,
          updatedAt: now,
          activities: const <String, ActivityProgressRecord>{},
          exams: const <String, ExamProgressRecord>{},
        ),
      ],
    );

    await pumpApp(tester, progressController: progressController);
    await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relaciones y violencia digital'));
    await tester.pumpAndSettle();

    expect(find.text('6 actividades'), findsOneWidget);
    expect(find.text('4 de 6 cápsulas vistas'), findsOneWidget);
    expect(find.text('4 de 4 cápsulas vistas'), findsNothing);
    expect(find.text(AppStrings.activitiesLockedByTheory), findsOneWidget);
    expect(find.text('0 de 12 actividades completadas'), findsNothing);
    expect(find.text('33%'), findsOneWidget);
    expect(
      progressController
          .snapshotFor('relations_violence_digital')
          .totalTheoryPages,
      6,
    );
    expect(
      progressController
          .snapshotFor('relations_violence_digital')
          .totalActivities,
      6,
    );
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

  testWidgets('navega entre las seis cápsulas teóricas', (tester) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();

    expect(repository.loadLessonPagesCalls, 2);
    expect(find.text('1 de 6'), findsOneWidget);
    expect(find.text('¿Qué es la violencia digital?'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isFalse,
    );

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text('2 de 6'), findsOneWidget);
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
    expect(find.text('3 de 6'), findsOneWidget);
    expect(find.text('Consentimiento y contenido íntimo'), findsOneWidget);

    await tester.tap(find.text(AppStrings.previous));
    await tester.pumpAndSettle();
    expect(find.text('2 de 6'), findsOneWidget);

    while (find.text(AppStrings.startActivities).evaluate().isEmpty) {
      await tester.tap(find.text(AppStrings.next));
      await tester.pumpAndSettle();
    }
    expect(find.text('6 de 6'), findsOneWidget);
    expect(
      find.text('Recuperación, apoyo y seguridad inmediata'),
      findsOneWidget,
    );
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
    await advanceTheoryToActivities(tester);

    expect(find.text(AppStrings.activitiesTitle), findsWidgets);
    expect(find.text(AppStrings.firstActivityBlock), findsOneWidget);
    expect(find.text(AppStrings.secondActivityBlock), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.firstActivityBlock));
    await tester.tap(find.text(AppStrings.firstActivityBlock));
    await tester.pumpAndSettle();

    expect(repository.loadQuizQuestionsCalls, 7);
    expect(find.text(AppStrings.quizTitle), findsOneWidget);
    expect(find.text('Actividad 1 de 12'), findsNothing);
    expect(find.text('Pregunta 1 de 12'), findsOneWidget);
  });

  testWidgets('el menú renderiza seis actividades reales del repositorio', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.activitiesTitle));
    await tester.tap(find.text(AppStrings.activitiesTitle));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.completeTheoryToUnlockActivities),
      findsOneWidget,
    );
    expect(find.text(AppStrings.activitiesTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await advanceTheoryToActivities(tester);

    await tester.ensureVisible(find.text(AppStrings.activitiesTitle));

    expect(repository.loadActivitiesCalls, 2);
    expect(repository.loadFinalExamConfigCalls, 1);
    expect(find.text(AppStrings.firstActivityBlock), findsOneWidget);
    expect(find.text(AppStrings.secondActivityBlock), findsOneWidget);
    expect(find.text(AppStrings.thirdActivityBlock), findsOneWidget);

    await tester.ensureVisible(find.text('Actividad 6'));

    expect(find.text('Actividad 4'), findsOneWidget);
    expect(find.text('Actividad 5'), findsOneWidget);
    expect(find.text('Actividad 6'), findsOneWidget);
    expect(find.text(AppStrings.finalExamTitle), findsOneWidget);
    expect(find.text(AppStrings.finalExamLocked), findsOneWidget);
    expect(find.text(AppStrings.locked), findsNWidgets(5));

    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.completePreviousActivity), findsOneWidget);
    expect(
      find.text('¿Cuál es un ejemplo de violencia digital?'),
      findsNothing,
    );
  });

  testWidgets(
    'el examen final se desbloquea al completar las seis actividades exactas',
    (tester) async {
      final progressController = CategoryProgressController();
      progressController.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _completedActivitiesRecord(repository.activities),
        ],
      );

      await pumpApp(tester, progressController: progressController);
      await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relaciones y violencia digital'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.activitiesTitle));
      await tester.tap(find.text(AppStrings.activitiesTitle));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(AppStrings.finalExamTitle));

      expect(find.text(AppStrings.finalExamLocked), findsNothing);
      expect(find.text(AppStrings.finalExamTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.finalExamTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'El banco actual tiene 12 preguntas. '
          'El examen final necesita 15 para iniciar.',
        ),
        findsOneWidget,
      );
      expect(
        progressController
            .examProgressFor(
              categoryId: FinalExamConfigs.relationsViolence.categoryId,
              examId: FinalExamConfigs.relationsViolence.id,
            )
            .attemptCount,
        0,
      );
    },
  );

  testWidgets('volver desde actividades abre el detalle de categorÃ­a', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.ensureVisible(find.text(AppStrings.theoryTitle));
    await tester.tap(find.text(AppStrings.theoryTitle));
    await tester.pumpAndSettle();
    await advanceTheoryToActivities(tester);

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

    expect(find.text('Pregunta 1 de 12'), findsOneWidget);
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

Finder _firstVisibleText(WidgetTester tester, List<Finder> candidates) {
  for (final candidate in candidates) {
    if (candidate.evaluate().isNotEmpty) {
      return candidate;
    }
  }

  fail('No visible answer option matched the expected candidates.');
}

CategoryProgressRecord _completedActivitiesRecord(
  List<LearningActivity> activities,
) {
  final now = DateTime.utc(2026, 8, 27, 12);
  final activityRecords = <String, ActivityProgressRecord>{
    for (final activity in activities)
      activity.id: ActivityProgressRecord(
        activityId: activity.id,
        status: ActivityProgressStatus.completed,
        attemptCount: 1,
        bestCorrectAnswers: 2,
        bestTotalQuestions: 2,
        bestPercentage: 100,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      ),
  };

  return CategoryProgressRecord(
    categoryId: FinalExamConfigs.relationsViolence.categoryId,
    lessonId: 'relations_violence',
    status: CategoryProgressStatus.completed,
    viewedLessonPageIds: const <String>[
      'what_is_digital_violence',
      'control_is_not_care',
      'consent_and_intimate_content',
      'how_to_act',
      'threats_evidence_safe_response',
      'recovery_support_immediate_safety',
    ],
    completedActivityIds: activities.map((activity) => activity.id).toList(),
    totalLessonPages: 6,
    totalActivities: activities.length,
    startedAt: now,
    lastActivityAt: now,
    completedAt: now,
    updatedAt: now,
    activities: activityRecords,
    exams: const <String, ExamProgressRecord>{},
  );
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

class _FakeContentRepository implements ContentRepository {
  int loadCategoriesCalls = 0;
  int loadLessonPagesCalls = 0;
  int loadActivitiesCalls = 0;
  int loadQuizQuestionsCalls = 0;
  int loadFinalExamConfigCalls = 0;

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
    LessonPage(
      id: 'threats_evidence_safe_response',
      order: 5,
      title: 'Amenazas, evidencia y respuesta segura',
      body:
          'La evidencia digital puede incluir capturas completas, nombres de '
          'usuario, enlaces, fechas y otros registros.',
    ),
    LessonPage(
      id: 'recovery_support_immediate_safety',
      order: 6,
      title: 'Recuperación, apoyo y seguridad inmediata',
      body:
          'Después de una situación de control, revisa contraseñas, sesiones '
          'abiertas, dispositivos vinculados y permisos de ubicación.',
    ),
  ];

  final activities = const <LearningActivity>[
    LearningActivity(
      id: 'relations_violence_activity_01',
      categoryId: 'relations_violence_digital',
      title: AppStrings.firstActivityBlock,
      order: 1,
    ),
    LearningActivity(
      id: 'relations_violence_activity_02',
      categoryId: 'relations_violence_digital',
      title: AppStrings.secondActivityBlock,
      order: 2,
    ),
    LearningActivity(
      id: 'relations_violence_activity_03',
      categoryId: 'relations_violence_digital',
      title: AppStrings.thirdActivityBlock,
      order: 3,
    ),
    LearningActivity(
      id: 'relations_violence_activity_04',
      categoryId: 'relations_violence_digital',
      title: 'Actividad 4',
      order: 4,
    ),
    LearningActivity(
      id: 'relations_violence_activity_05',
      categoryId: 'relations_violence_digital',
      title: 'Actividad 5',
      order: 5,
    ),
    LearningActivity(
      id: 'relations_violence_activity_06',
      categoryId: 'relations_violence_digital',
      title: 'Actividad 6',
      order: 6,
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
  Future<List<LearningActivity>> loadActivities(String categoryId) async {
    loadActivitiesCalls += 1;
    return activities;
  }

  @override
  Future<List<QuizQuestion>> loadQuizQuestions(
    String categoryId, {
    String? activityId,
  }) async {
    loadQuizQuestionsCalls += 1;
    return quizQuestions
        .where((question) {
          return question.categoryId == categoryId &&
              (activityId == null || question.activityId == activityId);
        })
        .toList(growable: false);
  }

  @override
  Future<FinalExamConfig?> loadFinalExamConfig(String categoryId) async {
    loadFinalExamConfigCalls += 1;
    return FinalExamConfigs.forCategory(categoryId);
  }
}

List<QuizQuestion> _buildQuizQuestions() {
  return <QuizQuestion>[
    const QuizQuestion(
      id: 'activity_1',
      categoryId: 'relations_violence_digital',
      activityId: 'relations_violence_activity_01',
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
      categoryId: 'relations_violence_digital',
      activityId: 'relations_violence_activity_01',
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
        categoryId: 'relations_violence_digital',
        activityId: 'relations_violence_activity_01',
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
