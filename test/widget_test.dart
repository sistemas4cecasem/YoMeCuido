import 'package:demo_yomecuido/app/app.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/app/category_progress_controller.dart';
import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/category_progress.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/leaderboard_entry.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/auth_repository.dart';
import 'package:demo_yomecuido/data/repositories/content_repository.dart';
import 'package:demo_yomecuido/data/repositories/leaderboard_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:demo_yomecuido/shared/widgets/lesson_progress_bar.dart';
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
        userProfileRepository: _FakeUserProfileRepository(),
        leaderboardRepository: const _FakeLeaderboardRepository(),
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
    for (var activity = 1; activity <= 10; activity += 1) {
      await answerActivity(
        tester,
        activity,
        correctly: activity <= correctAnswers,
      );

      final nextButton = find.text(
        activity == 10 ? AppStrings.seeResult : AppStrings.nextActivity,
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  Future<void> openCategories(
    WidgetTester tester, {
    CategoryProgressController? progressController,
  }) async {
    await pumpApp(tester, progressController: progressController);
    await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(
    WidgetTester tester, {
    CategoryProgressController? progressController,
  }) async {
    await openCategories(tester, progressController: progressController);
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
    expect(find.text(AppStrings.comingSoon), findsNothing);
    expect(repository.loadCategoriesCalls, 0);
  });

  testWidgets('trata y tráfico abre una lista vacía reutilizable', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text(AppStrings.traffickingTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.traffickingTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyCategoryGroup), findsOneWidget);
    expect(find.text(AppStrings.digitalSecurityTitle), findsNothing);
    expect(find.text('Relaciones y violencia digital'), findsNothing);
    expect(repository.loadCategoriesCalls, 1);
  });

  testWidgets('seguridad digital abre las categorías existentes', (
    tester,
  ) async {
    await openCategories(tester);

    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(repository.loadCategoriesCalls, 1);
    expect(find.text('Relaciones y violencia digital'), findsOneWidget);
  });

  testWidgets('seguridad digital filtra subcategorías de otros grupos', (
    tester,
  ) async {
    repository.categories = <Category>[
      ...repository.categories,
      const Category(
        id: 'trafficking_fundamentals',
        parentCategoryId: ParentCategoryIds.humanTrafficking,
        title: 'Conceptos fundamentales sobre trata y tráfico de personas',
        description: 'Contenido futuro.',
        iconName: 'health_and_safety_outlined',
        status: CategoryStatus.available,
        isEnabled: true,
        indicators: <String>['6 actividades'],
        objectives: <String>['Reconocer conceptos fundamentales.'],
        lessonId: 'trafficking_fundamentals',
      ),
    ];

    await openCategories(tester);

    expect(find.text('Relaciones y violencia digital'), findsOneWidget);
    expect(
      find.text('Conceptos fundamentales sobre trata y tráfico de personas'),
      findsNothing,
    );
  });

  testWidgets(
    'se muestran ocho categorías y solo la primera está desbloqueada',
    (tester) async {
      await openCategories(tester);

      for (final category in repository.categories) {
        expect(find.text(category.title), findsOneWidget);
      }

      expect(repository.categories, everyElement(isA<Category>()));
      expect(find.text(AppStrings.comingSoon), findsNothing);
      expect(
        find.text(AppStrings.categoryLockedByProgress),
        findsNWidgets(repository.categories.length - 1),
      );
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    },
  );

  testWidgets('las categorías bloqueadas no navegan', (tester) async {
    await openCategories(tester);

    await tester.tap(find.text('Protección de cuentas y autenticación'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.theoryTitle), findsNothing);
    expect(find.text(AppStrings.digitalSecurityTitle), findsOneWidget);
    expect(
      find.text(AppStrings.categoryLockedByProgressSnackBar),
      findsOneWidget,
    );
  });

  testWidgets(
    'la siguiente categoría se desbloquea al completar categoría y examen',
    (tester) async {
      final progressController = CategoryProgressController();
      progressController.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _completedActivitiesRecord(
            repository.activities,
            includeCompletedExam: true,
          ),
        ],
      );

      await openCategories(tester, progressController: progressController);

      expect(
        find.text(AppStrings.categoryLockedByProgress),
        findsNWidgets(repository.categories.length - 2),
      );

      await tester.tap(find.text('Protección de cuentas y autenticación'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.theoryTitle), findsOneWidget);
      expect(find.text('Protección de cuentas y autenticación'), findsWidgets);
    },
  );

  testWidgets(
    'un examen no aprobado mantiene bloqueada la siguiente categoría',
    (tester) async {
      final progressController = CategoryProgressController();
      progressController.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _completedActivitiesRecord(
            repository.activities,
            includeCompletedExam: true,
            examBestPercentage: 73,
          ),
        ],
      );

      await openCategories(tester, progressController: progressController);

      expect(
        progressController
            .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
            .examPassed(FinalExamConfigs.relationsViolence.id),
        isFalse,
      );
      await tester.tap(find.text('Protección de cuentas y autenticación'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.categoryLockedByProgressSnackBar),
        findsOneWidget,
      );
      expect(find.text(AppStrings.theoryTitle), findsNothing);
    },
  );

  testWidgets('un status antiguo completed sin examen aprobado no desbloquea', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _completedActivitiesRecord(repository.activities),
      ],
    );

    await openCategories(tester, progressController: progressController);

    expect(
      progressController
          .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
          .status,
      CategoryProgressStatus.completed,
    );
    expect(
      progressController
          .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
          .subcategoryCompleted,
      isFalse,
    );
    await tester.tap(find.text('Protección de cuentas y autenticación'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.categoryLockedByProgressSnackBar),
      findsOneWidget,
    );
    expect(find.text(AppStrings.theoryTitle), findsNothing);
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
    expect(find.text(AppStrings.finalExamTitle), findsOneWidget);
    expect(find.text(AppStrings.summaryTitle), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('learning_route_step_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('learning_route_step_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('learning_route_step_3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('learning_route_step_4')),
      findsOneWidget,
    );
  });

  testWidgets('la ruta de aprendizaje muestra examen bloqueado', (
    tester,
  ) async {
    await openDetail(tester);

    expect(find.text(AppStrings.finalExamTitle), findsOneWidget);
    expect(find.text(AppStrings.finalExamLocked), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.finalExamTitle));
    await tester.tap(
      find.byKey(const ValueKey<String>('learning_route_step_3')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.finalExamLocked), findsWidgets);
    expect(find.text('Pregunta 1 de 15'), findsNothing);
  });

  testWidgets('la ruta de aprendizaje muestra examen disponible', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _completedActivitiesRecord(repository.activities),
      ],
    );

    await openDetail(tester, progressController: progressController);

    expect(
      find.text(
        '${FinalExamConfigs.relationsViolence.questionCount} preguntas · '
        '${AppStrings.available}',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text(AppStrings.finalExamTitle));
    await tester.tap(
      find.byKey(const ValueKey<String>('learning_route_step_3')),
    );
    await tester.pumpAndSettle();

    final progressBar = tester.widget<LessonProgressBar>(
      find.byType(LessonProgressBar),
    );
    expect(progressBar.currentStep, 1);
    expect(
      progressBar.totalSteps,
      FinalExamConfigs.relationsViolence.questionCount,
    );
  });

  testWidgets('la ruta de aprendizaje muestra reintento de examen', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _completedActivitiesRecord(
          repository.activities,
          includeCompletedExam: true,
          examBestPercentage: 73,
        ),
      ],
    );

    await openDetail(tester, progressController: progressController);

    expect(find.text('Reintentar · Mejor resultado 73%'), findsOneWidget);
  });

  testWidgets('la ruta de aprendizaje muestra examen aprobado', (tester) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _completedActivitiesRecord(
          repository.activities,
          includeCompletedExam: true,
          examBestPercentage: 87,
        ),
      ],
    );

    await openDetail(tester, progressController: progressController);

    expect(find.text('Aprobado · Mejor resultado 87%'), findsOneWidget);
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
    expect(find.text('7%'), findsOneWidget);
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

  testWidgets('detalle y resumen muestran el mismo progreso ponderado', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _completedActivitiesRecord(repository.activities),
      ],
    );

    await openDetail(tester, progressController: progressController);

    expect(find.text('85%'), findsOneWidget);
    await tester.ensureVisible(find.text(AppStrings.summaryTitle).last);
    await tester.tap(find.text(AppStrings.summaryTitle).last);
    await tester.pumpAndSettle();

    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets(
    'el resumen separa progreso, actividades aprobadas, rendimiento y puntaje',
    (tester) async {
      final progressController = CategoryProgressController();
      progressController.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _summaryProgressRecord(
            repository.activities,
            activityBestPercentages: const <int>[80, 90, 100, 80, 85, 70],
            activityAttemptCounts: const <int>[1, 1, 3, 1, 1, 1],
            activityPoints: const <int>[70, 80, 120, 70, 80, 30],
          ),
        ],
      );

      await _openCategorySummary(tester, progressController);

      expect(find.text('73%'), findsOneWidget);
      expect(find.text('5 / 6'), findsOneWidget);
      expect(find.text('Aprobadas'), findsOneWidget);
      expect(find.text('450 pts'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Intentos'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Mejor resultado'), findsOneWidget);
      expect(find.text('En progreso'), findsOneWidget);
      expect(find.text('Subcategoría completada'), findsNothing);
      expect(find.text('Examen final: Bloqueado'), findsOneWidget);
    },
  );

  testWidgets(
    'el resumen muestra examen disponible sin completar subcategoría',
    (tester) async {
      final progressController = CategoryProgressController();
      progressController.hydrateFromRecords(
        uid: 'uid-123',
        records: <CategoryProgressRecord>[
          _summaryProgressRecord(
            repository.activities,
            activityBestPercentages: const <int>[80, 80, 80, 80, 80, 80],
          ),
        ],
      );

      await _openCategorySummary(tester, progressController);

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('6 / 6'), findsWidgets);
      expect(find.text('Examen final: Disponible'), findsOneWidget);
      expect(find.text('En progreso'), findsOneWidget);
      expect(find.text('Subcategoría completada'), findsNothing);
    },
  );

  testWidgets('el resumen diferencia examen reprobado y examen aprobado', (
    tester,
  ) async {
    final failedController = CategoryProgressController();
    failedController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _summaryProgressRecord(
          repository.activities,
          activityBestPercentages: const <int>[80, 80, 80, 80, 80, 80],
          examBestPercentage: 73,
        ),
      ],
    );

    await _openCategorySummary(tester, failedController);

    expect(find.text('85%'), findsOneWidget);
    expect(
      find.text(
        'Examen final: No aprobado / Reintentar · Mejor resultado: 73%',
      ),
      findsOneWidget,
    );
    expect(find.text('Subcategoría completada'), findsNothing);

    final passedController = CategoryProgressController();
    passedController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _summaryProgressRecord(
          repository.activities,
          activityBestPercentages: const <int>[80, 80, 80, 80, 80, 80],
          examBestPercentage: 80,
        ),
      ],
    );

    await _openCategorySummary(tester, passedController);

    expect(find.text('100%'), findsOneWidget);
    expect(
      find.text('Examen final: Aprobado · Mejor resultado: 80%'),
      findsOneWidget,
    );
    expect(find.text('Subcategoría completada'), findsOneWidget);
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

    expect(repository.loadQuizQuestionsCalls, 2);
    expect(find.text(AppStrings.quizTitle), findsOneWidget);
    expect(find.text('Actividad 1 de 12'), findsNothing);
    expect(find.text('Pregunta 1 de 10'), findsNothing);
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
    expect(find.text(AppStrings.finalExamTitle), findsNothing);
    expect(find.text(AppStrings.finalExamLocked), findsNothing);
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
      await tester.ensureVisible(find.text(AppStrings.finalExamTitle));

      expect(find.text(AppStrings.finalExamLocked), findsNothing);
      expect(find.text(AppStrings.finalExamTitle), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('learning_route_step_3')),
      );
      await tester.pumpAndSettle();

      final progressBar = tester.widget<LessonProgressBar>(
        find.byType(LessonProgressBar),
      );
      expect(progressBar.currentStep, 1);
      expect(
        progressBar.totalSteps,
        FinalExamConfigs.relationsViolence.questionCount,
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

  testWidgets('el examen final exige teoría completa y actividades aprobadas', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 27, 12);
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        CategoryProgressRecord(
          categoryId: FinalExamConfigs.relationsViolence.categoryId,
          lessonId: 'relations_violence',
          status: CategoryProgressStatus.inProgress,
          viewedLessonPageIds: const <String>[
            'what_is_digital_violence',
            'control_is_not_care',
          ],
          completedActivityIds: repository.activities
              .map((activity) => activity.id)
              .toList(),
          totalLessonPages: 6,
          totalActivities: repository.activities.length,
          startedAt: now,
          lastActivityAt: now,
          completedAt: null,
          updatedAt: now,
          activities: _passedActivityRecords(repository.activities, now),
          exams: const <String, ExamProgressRecord>{},
        ),
      ],
    );

    expect(
      progressController
          .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
          .examUnlocked,
      isFalse,
    );

    final incompleteActivityController = CategoryProgressController();
    incompleteActivityController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{
            for (final activity in repository.activities)
              activity.id: activity == repository.activities.last ? 70 : 80,
          },
        ),
      ],
    );

    expect(
      incompleteActivityController
          .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
          .examUnlocked,
      isFalse,
    );
  });

  testWidgets('una actividad no aprobada no desbloquea la siguiente', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{repository.activities[0].id: 70},
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    expect(find.text('Reintentar'), findsOneWidget);
    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.completePreviousActivity), findsOneWidget);
    expect(
      find.text('¿Cuál es un ejemplo de violencia digital?'),
      findsNothing,
    );
  });

  testWidgets('una actividad aprobada desbloquea la siguiente', (tester) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{repository.activities[0].id: 80},
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    expect(find.text('Completada'), findsOneWidget);
    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.quizTitle), findsOneWidget);
  });

  testWidgets('un reintento aprobado desbloquea la siguiente actividad', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{repository.activities[0].id: 90},
          attemptCounts: <String, int>{repository.activities[0].id: 2},
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    expect(
      progressController
          .activityProgressFor(
            categoryId: FinalExamConfigs.relationsViolence.categoryId,
            activityId: repository.activities[0].id,
          )
          .bestPercentage,
      90,
    );
    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.quizTitle), findsOneWidget);
  });

  testWidgets('un intento posterior peor no revierte el desbloqueo', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{repository.activities[0].id: 90},
          attemptCounts: <String, int>{repository.activities[0].id: 2},
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    final firstProgress = progressController.activityProgressFor(
      categoryId: FinalExamConfigs.relationsViolence.categoryId,
      activityId: repository.activities[0].id,
    );
    expect(firstProgress.bestPercentage, 90);
    expect(firstProgress.isPassed, isTrue);
    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.quizTitle), findsOneWidget);
  });

  testWidgets('una segunda actividad no aprobada no desbloquea la tercera', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{
            repository.activities[0].id: 80,
            repository.activities[1].id: 70,
          },
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    await tester.ensureVisible(find.text(AppStrings.thirdActivityBlock));
    await tester.tap(find.text(AppStrings.thirdActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.completePreviousActivity), findsOneWidget);
    expect(
      find.text('¿Cuál es un ejemplo de violencia digital?'),
      findsNothing,
    );
    await tester.ensureVisible(find.text(AppStrings.secondActivityBlock));
    await tester.tap(find.text(AppStrings.secondActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.quizTitle), findsOneWidget);
  });

  testWidgets('una segunda actividad aprobada desbloquea la tercera', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{
            repository.activities[0].id: 80,
            repository.activities[1].id: 80,
          },
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    await tester.ensureVisible(find.text(AppStrings.thirdActivityBlock));
    await tester.tap(find.text(AppStrings.thirdActivityBlock));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.quizTitle), findsOneWidget);
  });

  testWidgets('el desbloqueo secuencial recorre todas las actividades reales', (
    tester,
  ) async {
    final progressController = CategoryProgressController();
    progressController.hydrateFromRecords(
      uid: 'uid-123',
      records: <CategoryProgressRecord>[
        _activitySequenceRecord(
          repository.activities,
          bestPercentages: <String, int>{
            for (final activity in repository.activities) activity.id: 80,
          },
        ),
      ],
    );

    await _openActivitiesMenu(tester, progressController);

    for (final activity in repository.activities) {
      expect(
        progressController
            .snapshotFor(FinalExamConfigs.relationsViolence.categoryId)
            .activityPassed(activity.id),
        isTrue,
      );
      await tester.ensureVisible(find.text(activity.title));
      expect(find.text(activity.title), findsOneWidget);
    }

    expect(find.text(AppStrings.locked), findsNothing);
  });

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
    await completeActivities(tester, correctAnswers: 10);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('10 de 10 correctas'), findsOneWidget);

    await tester.tap(find.text(AppStrings.repeatLesson));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 10'), findsNothing);
    expect(find.text(AppStrings.lessonCompleted), findsNothing);
    expect(find.text(AppStrings.quizTitle), findsOneWidget);
    expect(find.text(AppStrings.submitAnswer), findsNothing);
  });

  testWidgets('repetir lecci\u00f3n reinicia el puntaje', (tester) async {
    await openQuiz(tester);
    await completeActivities(tester, correctAnswers: 10);

    await tester.tap(find.text(AppStrings.repeatLesson));
    await tester.pumpAndSettle();

    await completeActivities(tester, correctAnswers: 0);

    expect(find.text(AppStrings.lessonCompleted), findsOneWidget);
    expect(find.text('0 de 10 correctas'), findsOneWidget);
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

Future<void> _openActivitiesMenu(
  WidgetTester tester,
  CategoryProgressController progressController,
) async {
  await tester.pumpWidget(
    YoMeCuidoApp(
      contentRepository: _FakeContentRepository(),
      authRepository: const _SignedInAuthRepository(),
      userProfileRepository: _FakeUserProfileRepository(),
      leaderboardRepository: const _FakeLeaderboardRepository(),
      progressController: progressController,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Relaciones y violencia digital'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(AppStrings.activitiesTitle));
  await tester.tap(find.text(AppStrings.activitiesTitle));
  await tester.pumpAndSettle();
}

Future<void> _openCategorySummary(
  WidgetTester tester,
  CategoryProgressController progressController,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    YoMeCuidoApp(
      contentRepository: _FakeContentRepository(),
      authRepository: const _SignedInAuthRepository(),
      userProfileRepository: _FakeUserProfileRepository(),
      leaderboardRepository: const _FakeLeaderboardRepository(),
      progressController: progressController,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.digitalSecurityTitle).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Relaciones y violencia digital'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(AppStrings.summaryTitle).last);
  await tester.tap(find.text(AppStrings.summaryTitle).last);
  await tester.pumpAndSettle();
}

CategoryProgressRecord _activitySequenceRecord(
  List<LearningActivity> activities, {
  required Map<String, int> bestPercentages,
  Map<String, int> attemptCounts = const <String, int>{},
}) {
  final now = DateTime.utc(2026, 8, 27, 12);
  final activityRecords = <String, ActivityProgressRecord>{
    for (final activity in activities)
      if (bestPercentages.containsKey(activity.id))
        activity.id: ActivityProgressRecord(
          activityId: activity.id,
          status: ActivityProgressStatus.completed,
          attemptCount: attemptCounts[activity.id] ?? 1,
          bestCorrectAnswers: (bestPercentages[activity.id]! / 10).round(),
          bestTotalQuestions: 10,
          bestPercentage: bestPercentages[activity.id]!,
          lastAttemptAt: now,
          completedAt: now,
          updatedAt: now,
        ),
  };

  return CategoryProgressRecord(
    categoryId: FinalExamConfigs.relationsViolence.categoryId,
    lessonId: 'relations_violence',
    status: CategoryProgressStatus.inProgress,
    viewedLessonPageIds: const <String>[
      'what_is_digital_violence',
      'control_is_not_care',
      'consent_and_intimate_content',
      'how_to_act',
      'threats_evidence_safe_response',
      'recovery_support_immediate_safety',
    ],
    completedActivityIds: bestPercentages.keys.toList(),
    totalLessonPages: 6,
    totalActivities: activities.length,
    startedAt: now,
    lastActivityAt: now,
    completedAt: null,
    updatedAt: now,
    activities: activityRecords,
    exams: const <String, ExamProgressRecord>{},
  );
}

CategoryProgressRecord _summaryProgressRecord(
  List<LearningActivity> activities, {
  required List<int> activityBestPercentages,
  List<int> activityAttemptCounts = const <int>[],
  List<int> activityPoints = const <int>[],
  int? examBestPercentage,
}) {
  final now = DateTime.utc(2026, 8, 27, 12);
  final activityRecords = <String, ActivityProgressRecord>{
    for (
      var index = 0;
      index < activities.length && index < activityBestPercentages.length;
      index += 1
    )
      activities[index].id: ActivityProgressRecord(
        activityId: activities[index].id,
        status: ActivityProgressStatus.completed,
        attemptCount: index < activityAttemptCounts.length
            ? activityAttemptCounts[index]
            : 1,
        activityPoints: index < activityPoints.length
            ? activityPoints[index]
            : 0,
        bestCorrectAnswers: (activityBestPercentages[index] / 10).round(),
        bestTotalQuestions: 10,
        bestPercentage: activityBestPercentages[index],
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      ),
  };

  return CategoryProgressRecord(
    categoryId: FinalExamConfigs.relationsViolence.categoryId,
    lessonId: 'relations_violence',
    status: CategoryProgressStatus.inProgress,
    viewedLessonPageIds: const <String>[
      'what_is_digital_violence',
      'control_is_not_care',
      'consent_and_intimate_content',
      'how_to_act',
      'threats_evidence_safe_response',
      'recovery_support_immediate_safety',
    ],
    completedActivityIds: activityRecords.keys.toList(),
    totalLessonPages: 6,
    totalActivities: activities.length,
    startedAt: now,
    lastActivityAt: now,
    completedAt: null,
    updatedAt: now,
    activities: activityRecords,
    exams: examBestPercentage == null
        ? const <String, ExamProgressRecord>{}
        : <String, ExamProgressRecord>{
            FinalExamConfigs.relationsViolence.id: ExamProgressRecord(
              examId: FinalExamConfigs.relationsViolence.id,
              status: ActivityProgressStatus.completed,
              attemptCount: 1,
              bestCorrectAnswers: (examBestPercentage * 15 / 100).round(),
              bestTotalQuestions: 15,
              bestPercentage: examBestPercentage,
              lastAttemptAt: now,
              completedAt: now,
              updatedAt: now,
            ),
          },
  );
}

CategoryProgressRecord _completedActivitiesRecord(
  List<LearningActivity> activities, {
  bool includeCompletedExam = false,
  int examBestPercentage = 100,
}) {
  final now = DateTime.utc(2026, 8, 27, 12);
  final activityRecords = _passedActivityRecords(activities, now);

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
    exams: includeCompletedExam
        ? <String, ExamProgressRecord>{
            FinalExamConfigs.relationsViolence.id: ExamProgressRecord(
              examId: FinalExamConfigs.relationsViolence.id,
              status: ActivityProgressStatus.completed,
              attemptCount: 1,
              bestCorrectAnswers: (examBestPercentage * 15 / 100).round(),
              bestTotalQuestions: 15,
              bestPercentage: examBestPercentage,
              lastAttemptAt: now,
              completedAt: now,
              updatedAt: now,
            ),
          }
        : const <String, ExamProgressRecord>{},
  );
}

Map<String, ActivityProgressRecord> _passedActivityRecords(
  List<LearningActivity> activities,
  DateTime now,
) {
  return <String, ActivityProgressRecord>{
    for (final activity in activities)
      activity.id: ActivityProgressRecord(
        activityId: activity.id,
        status: ActivityProgressStatus.completed,
        attemptCount: 1,
        bestCorrectAnswers: 8,
        bestTotalQuestions: 10,
        bestPercentage: 80,
        lastAttemptAt: now,
        completedAt: now,
        updatedAt: now,
      ),
  };
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  const _FakeLeaderboardRepository();

  @override
  Stream<List<LeaderboardEntry>> watchTopEntries({
    int limit = LeaderboardRepository.defaultLimit,
  }) {
    return Stream<List<LeaderboardEntry>>.value(const <LeaderboardEntry>[]);
  }

  @override
  Future<LeaderboardUserPosition?> fetchUserPosition({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {
    return null;
  }

  @override
  Future<void> ensureEntryForCurrentUser({
    required String uid,
    required String username,
    required int totalPoints,
  }) async {}
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
    required String username,
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

class _FakeUserProfileRepository extends UserProfileRepository {
  _FakeUserProfileRepository() : super.testing();

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    return const UserProfile(
      username: 'diegonais',
      usernameNormalized: 'diegonais',
      email: 'persona@example.com',
      role: UserProfileRole.user,
      createdAt: null,
      updatedAt: null,
    );
  }
}

class _FakeContentRepository implements ContentRepository {
  int loadCategoriesCalls = 0;
  int loadLessonPagesCalls = 0;
  int loadActivitiesCalls = 0;
  int loadQuizQuestionsCalls = 0;
  int loadFinalExamConfigCalls = 0;

  List<Category> categories = const <Category>[
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
      description: 'Aprende a proteger tus cuentas.',
      iconName: 'lock_outline',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Proteger cuentas.'],
      lessonId: 'accounts_auth',
    ),
    Category(
      id: 'device_app_security',
      title: 'Seguridad de dispositivos y aplicaciones',
      description: 'Aprende a proteger tus dispositivos.',
      iconName: 'phone_android_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Proteger dispositivos.'],
      lessonId: 'device_security',
    ),
    Category(
      id: 'personal_data_privacy_identity',
      title: 'Datos personales, privacidad e identidad',
      description: 'Aprende a cuidar tus datos.',
      iconName: 'badge_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Cuidar datos personales.'],
      lessonId: 'privacy_identity',
    ),
    Category(
      id: 'phishing_social_engineering',
      title: 'Engaños, phishing e ingeniería social',
      description: 'Aprende a reconocer engaños.',
      iconName: 'mark_email_unread_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Reconocer engaños.'],
      lessonId: 'phishing_social',
    ),
    Category(
      id: 'digital_payments_consumption',
      title: 'Pagos, transferencias, compras y consumo digital',
      description: 'Aprende a comprar y pagar con seguridad.',
      iconName: 'credit_card_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Proteger pagos digitales.'],
      lessonId: 'payments_digital',
    ),
    Category(
      id: 'information_misinformation_ai',
      title: 'Información, desinformación e inteligencia artificial',
      description: 'Aprende a verificar información.',
      iconName: 'fact_check_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Verificar información.'],
      lessonId: 'information_ai',
    ),
    Category(
      id: 'incident_response_recovery',
      title: 'Respuesta y recuperación ante incidentes',
      description: 'Aprende a responder ante incidentes.',
      iconName: 'health_and_safety_outlined',
      status: CategoryStatus.available,
      isEnabled: true,
      indicators: <String>['6 actividades'],
      objectives: <String>['Responder ante incidentes.'],
      lessonId: 'incident_response',
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
    for (var activity = 1; activity <= 6; activity += 1)
      for (var question = 1; question <= 10; question += 1)
        QuizQuestion(
          id: 'activity_${activity}_q$question',
          categoryId: 'relations_violence_digital',
          activityId:
              'relations_violence_activity_${activity.toString().padLeft(2, '0')}',
          type: question == 2
              ? QuestionType.fillBlank
              : QuestionType.multipleChoice,
          statement: question == 1
              ? '¿Cuál es un ejemplo de violencia digital?'
              : question == 2
              ? 'Las capturas pueden servir como ______.'
              : 'Actividad de práctica $activity.$question',
          options: question == 2
              ? const <QuizOption>[]
              : <QuizOption>[
                  QuizOption(
                    id: 'safe_action_${activity}_$question',
                    text: question == 1
                        ? 'Controlar contraseñas y amenazar por mensajes.'
                        : 'Acción segura $activity.$question.',
                  ),
                  QuizOption(
                    id: 'unsafe_action_${activity}_$question',
                    text: question == 1
                        ? 'Actualizar una aplicación.'
                        : 'Acción insegura $activity.$question.',
                  ),
                ],
          correctAnswer: question == 2
              ? 'evidencia'
              : 'safe_action_${activity}_$question',
          acceptedAnswers: question == 2
              ? const <String>['evidencia']
              : <String>['safe_action_${activity}_$question'],
          feedback: question == 2
              ? 'Conviene almacenar las pruebas de manera segura.'
              : 'Esta acción ayuda a proteger y buscar apoyo.',
          capacity: 'responder',
          difficulty: question.isOdd ? 'básica' : 'intermedia',
        ),
    for (var index = 1; index <= 18; index += 1)
      QuizQuestion(
        id: 'exam_question_$index',
        categoryId: 'relations_violence_digital',
        activityId: 'relations_violence_exam_bank',
        type: QuestionType.multipleChoice,
        statement: 'Pregunta de examen $index',
        options: <QuizOption>[
          QuizOption(id: 'exam_correct_$index', text: 'Respuesta correcta'),
          QuizOption(id: 'exam_incorrect_$index', text: 'Respuesta incorrecta'),
        ],
        correctAnswer: 'exam_correct_$index',
        acceptedAnswers: <String>['exam_correct_$index'],
        feedback: 'Retroalimentación de examen.',
        capacity: 'responder',
        difficulty: index <= 6 ? 'básica' : 'intermedia',
      ),
  ];
}
