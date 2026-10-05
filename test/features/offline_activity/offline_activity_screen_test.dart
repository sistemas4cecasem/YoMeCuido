import 'dart:async';
import 'dart:math';

import 'package:demo_yomecuido/app/app_router.dart';
import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/data/models/offline_activity_question.dart';
import 'package:demo_yomecuido/data/repositories/offline_activity_repository.dart';
import 'package:demo_yomecuido/features/high_level_categories/high_level_categories_screen.dart';
import 'package:demo_yomecuido/features/offline_activity/offline_activity_screen.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:demo_yomecuido/shared/widgets/answer_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Inicio permite abrir actividad sin conexión cuando está offline',
    (tester) async {
      final connectivity = _offlineConnectivityService();
      await connectivity.start();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(),
          routes: {
            AppRoutes.offlineActivity: (_) => OfflineActivityScreen(
              repository: _FakeOfflineActivityRepository(_questions()),
            ),
          },
          home: HighLevelCategoriesScreen(
            connectivityService: connectivity,
            showBackButton: false,
            useScaffold: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.connectionRequired), findsNWidgets(2));
      await tester.ensureVisible(find.text(AppStrings.offlineActivityTitle));
      await tester.tap(find.text(AppStrings.offlineActivityTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineActivityIntroTitle), findsOneWidget);
      expect(find.text(AppStrings.offlineActivityStart), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      connectivity.dispose();
    },
  );

  testWidgets('actividad responde 20 preguntas y calcula resultado local', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        home: OfflineActivityScreen(
          repository: _FakeOfflineActivityRepository(_questions()),
          random: Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.offlineActivityStart));
    await tester.pumpAndSettle();

    final questions = _questions();
    for (var index = 0; index < 20; index += 1) {
      await _answerCurrentQuestion(tester, questions, correctly: index < 12);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.correct), findsNothing);
      expect(find.text(AppStrings.reviewAnswer), findsNothing);
      final states = tester
          .widgetList<AnswerOptionTile>(find.byType(AnswerOptionTile))
          .map((tile) => tile.state);
      expect(
        states.where((state) => state == AnswerOptionTileState.correct),
        hasLength(1),
      );
      expect(
        states.where((state) => state == AnswerOptionTileState.incorrect),
        hasLength(index < 12 ? 0 : 1),
      );
      await tester.tap(
        find.text(index == 19 ? AppStrings.seeResult : AppStrings.next),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text(AppStrings.offlineActivityResultTitle), findsOneWidget);
    expect(find.text('12 / 20'), findsOneWidget);
    expect(
      find.textContaining(AppStrings.offlineActivityCorrectAnswers),
      findsOneWidget,
    );
    expect(find.text(AppStrings.earnedPoints), findsNothing);
    expect(find.text(AppStrings.totalPoints), findsNothing);
    expect(find.text(AppStrings.pendingSyncTitle), findsNothing);
  });

  testWidgets(
    'marca las respuestas inmediatamente y habilita resultado offline',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(),
          home: OfflineActivityScreen(
            repository: _FakeOfflineActivityRepository(_questions()),
            random: Random(2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.offlineActivityStart));
      await tester.pumpAndSettle();

      final questions = _questions();
      for (var index = 0; index < 19; index += 1) {
        await _answerCurrentQuestion(tester, questions, correctly: true);
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.next));
        await tester.pumpAndSettle();
      }

      await _answerCurrentQuestion(tester, questions, correctly: false);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reviewAnswer), findsNothing);
      expect(find.text(AppStrings.seeResult), findsOneWidget);
      final resultButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.seeResult),
      );
      expect(resultButton.onPressed, isNotNull);

      await tester.tap(find.text(AppStrings.seeResult));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.offlineActivityResultTitle), findsOneWidget);
    },
  );

  testWidgets('volver al inicio no duplica rutas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data(),
        routes: {
          AppRoutes.offlineActivity: (_) => OfflineActivityScreen(
            repository: _FakeOfflineActivityRepository(_questions()),
            random: Random(3),
          ),
        },
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.offlineActivity);
              },
              child: const Text('Abrir'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.offlineActivityStart));
    await tester.pumpAndSettle();

    final questions = _questions();
    for (var index = 0; index < 20; index += 1) {
      await _answerCurrentQuestion(tester, questions, correctly: true);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(index == 19 ? AppStrings.seeResult : AppStrings.next),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(AppStrings.offlineActivityBackHome));
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text(AppStrings.offlineActivityResultTitle), findsNothing);
  });
}

Future<void> _answerCurrentQuestion(
  WidgetTester tester,
  List<OfflineActivityQuestion> questions, {
  required bool correctly,
}) async {
  final question = questions.firstWhere((candidate) {
    return find.text(candidate.statement).evaluate().isNotEmpty;
  });
  final correctAnswer = question.options.firstWhere(
    (option) => option.id == question.correctAnswer,
  );
  final selectedAnswer = correctly
      ? correctAnswer
      : question.options.firstWhere(
          (option) => option.id != question.correctAnswer,
        );

  await tester.ensureVisible(find.text(selectedAnswer.text));
  await tester.tap(find.text(selectedAnswer.text));
}

class _FakeOfflineActivityRepository implements OfflineActivityRepository {
  const _FakeOfflineActivityRepository(this.questions);

  final List<OfflineActivityQuestion> questions;

  @override
  Future<List<OfflineActivityQuestion>> loadQuestions() async => questions;
}

List<OfflineActivityQuestion> _questions() {
  return List<OfflineActivityQuestion>.generate(20, (index) {
    final id = 'offline_activity_q${(index + 1).toString().padLeft(2, '0')}';
    return OfflineActivityQuestion(
      id: id,
      statement: 'Pregunta ${index + 1}',
      options: [
        OfflineActivityOption(id: 'a', text: 'Respuesta correcta ${index + 1}'),
        const OfflineActivityOption(id: 'b', text: 'B'),
        const OfflineActivityOption(id: 'c', text: 'C'),
        const OfflineActivityOption(id: 'd', text: 'D'),
      ],
      correctAnswer: 'a',
    );
  }, growable: false);
}

ConnectivityService _offlineConnectivityService() {
  return ConnectivityService(
    networkMonitor: _FakeNetworkInterfaceMonitor(hasInterface: false),
    backendProbe: _FakeBackendConnectivityProbe(),
  );
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  _FakeNetworkInterfaceMonitor({required this.hasInterface});

  final bool hasInterface;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => hasInterface;

  @override
  Stream<bool> get onNetworkInterfaceChanged => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeBackendConnectivityProbe implements BackendConnectivityProbe {
  @override
  Future<bool> canReachBackend({required Duration timeout}) async => false;
}
