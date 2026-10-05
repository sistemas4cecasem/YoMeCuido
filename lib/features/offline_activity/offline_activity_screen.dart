import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/offline_activity_question.dart';
import '../../data/repositories/offline_activity_repository.dart';
import '../../shared/widgets/answer_option_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/lesson_progress_bar.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';

class OfflineActivityScreen extends StatefulWidget {
  const OfflineActivityScreen({
    OfflineActivityRepository? repository,
    Random? random,
    super.key,
  }) : _repository = repository ?? const AssetOfflineActivityRepository(),
       _random = random;

  final OfflineActivityRepository _repository;
  final Random? _random;

  @override
  State<OfflineActivityScreen> createState() => _OfflineActivityScreenState();
}

class _OfflineActivityScreenState extends State<OfflineActivityScreen> {
  late Future<List<OfflineActivityQuestion>> _questionsFuture;
  List<OfflineActivityQuestion> _questions = const <OfflineActivityQuestion>[];
  final Map<String, String> _answersByQuestionId = <String, String>{};
  var _currentIndex = 0;
  var _started = false;
  var _completed = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget._repository.loadQuestions();
  }

  Future<void> _retryLoad() async {
    setState(() {
      _questionsFuture = widget._repository.loadQuestions();
    });
  }

  void _start(List<OfflineActivityQuestion> questions) {
    setState(() {
      _questions = _shuffledQuestions(questions);
      _answersByQuestionId.clear();
      _currentIndex = 0;
      _started = true;
      _completed = false;
    });
  }

  void _selectAnswer(String questionId, String optionId) {
    setState(() {
      _answersByQuestionId[questionId] = optionId;
    });
  }

  void _continue() {
    if (_currentIndex >= _questions.length - 1) {
      setState(() {
        _completed = true;
      });
      return;
    }

    setState(() {
      _currentIndex += 1;
    });
  }

  void _repeat() {
    setState(() {
      _questions = _shuffledQuestions(_questions);
      _answersByQuestionId.clear();
      _currentIndex = 0;
      _started = true;
      _completed = false;
    });
  }

  List<OfflineActivityQuestion> _shuffledQuestions(
    List<OfflineActivityQuestion> questions,
  ) {
    final random = widget._random ?? Random();
    final shuffled = questions
        .map((question) {
          final options = List<OfflineActivityOption>.of(question.options)
            ..shuffle(random);
          return question.copyWith(options: options);
        })
        .toList(growable: false);
    return shuffled..shuffle(random);
  }

  Future<bool> _confirmExitIfNeeded() async {
    if (!_started || _completed || _answersByQuestionId.isEmpty) {
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.exitOfflineActivityTitle),
          content: const Text(AppStrings.exitOfflineActivityBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.keepLearning),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.exitOfflineActivity),
            ),
          ],
        );
      },
    );

    return shouldExit ?? false;
  }

  Future<void> _handleBack() async {
    final canExit = await _confirmExitIfNeeded();
    if (!mounted || !canExit) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_started || _completed || _answersByQuestionId.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: AppScaffold(
        title: AppStrings.offlineActivityTitle,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.close_outlined),
            tooltip: AppStrings.close,
          ),
        ],
        child: FutureBuilder<List<OfflineActivityQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _OfflineActivityError(onRetry: _retryLoad);
            }

            final questions = snapshot.data!;
            if (!_started) {
              return _OfflineActivityIntro(onStart: () => _start(questions));
            }

            if (_completed) {
              return _OfflineActivityResult(
                questions: _questions,
                answersByQuestionId: _answersByQuestionId,
                onRepeat: _repeat,
                onBackHome: () => Navigator.of(context).pop(),
              );
            }

            final question = _questions[_currentIndex];
            return _OfflineQuestionView(
              question: question,
              currentIndex: _currentIndex,
              totalQuestions: _questions.length,
              selectedOptionId: _answersByQuestionId[question.id],
              onSelect: (optionId) => _selectAnswer(question.id, optionId),
              onContinue: _continue,
            );
          },
        ),
      ),
    );
  }
}

class _OfflineActivityIntro extends StatelessWidget {
  const _OfflineActivityIntro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Card(
        color: colors.surfaceStrong,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.offline_bolt_outlined,
                color: colors.orangeDark,
                size: 44,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.offlineActivityIntroTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.offlineActivityIntroBody,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: AppStrings.offlineActivityStart,
                icon: Icons.play_arrow_outlined,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineQuestionView extends StatelessWidget {
  const _OfflineQuestionView({
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.selectedOptionId,
    required this.onSelect,
    required this.onContinue,
  });

  final OfflineActivityQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final String? selectedOptionId;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final questionNumber = currentIndex + 1;
    final isLastQuestion = questionNumber == totalQuestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${AppStrings.offlineActivityQuestionCounter} $questionNumber de $totalQuestions',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        LessonProgressBar(
          currentStep: questionNumber,
          totalSteps: totalQuestions,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              color: colors.surfaceStrong,
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(question.statement, style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    for (final option in question.options) ...[
                      AnswerOptionTile(
                        text: option.text,
                        state: _optionState(option.id),
                        onTap: selectedOptionId == null
                            ? () => onSelect(option.id)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: isLastQuestion ? AppStrings.seeResult : AppStrings.next,
          icon: isLastQuestion
              ? Icons.fact_check_outlined
              : Icons.arrow_forward_outlined,
          onPressed: selectedOptionId == null ? null : onContinue,
        ),
      ],
    );
  }

  AnswerOptionTileState _optionState(String optionId) {
    if (selectedOptionId == null) {
      return AnswerOptionTileState.idle;
    }
    if (question.isCorrectAnswer(optionId)) {
      return AnswerOptionTileState.correct;
    }
    if (selectedOptionId == optionId) {
      return AnswerOptionTileState.incorrect;
    }
    return AnswerOptionTileState.idle;
  }
}

class _OfflineActivityResult extends StatelessWidget {
  const _OfflineActivityResult({
    required this.questions,
    required this.answersByQuestionId,
    required this.onRepeat,
    required this.onBackHome,
  });

  final List<OfflineActivityQuestion> questions;
  final Map<String, String> answersByQuestionId;
  final VoidCallback onRepeat;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final correctAnswers = questions.where((question) {
      return question.isCorrectAnswer(answersByQuestionId[question.id] ?? '');
    }).length;
    final percentage = ((correctAnswers / questions.length) * 100).round();
    final message = _messageFor(correctAnswers);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: colors.surfaceStrong,
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt_outlined,
                    color: colors.orangeDark,
                    size: 44,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.offlineActivityResultTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '$correctAnswers / ${questions.length}',
                    style: textTheme.displaySmall?.copyWith(
                      color: colors.orangeDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppStrings.offlineActivityCorrectAnswers} ($percentage%)',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: AppStrings.offlineActivityRepeat,
            icon: Icons.refresh_outlined,
            onPressed: onRepeat,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: AppStrings.offlineActivityBackHome,
            icon: Icons.home_outlined,
            onPressed: onBackHome,
          ),
        ],
      ),
    );
  }

  String _messageFor(int correctAnswers) {
    if (correctAnswers >= 16) {
      return AppStrings.offlineActivityResultHigh;
    }
    if (correctAnswers >= 10) {
      return AppStrings.offlineActivityResultMedium;
    }
    return AppStrings.offlineActivityResultLow;
  }
}

class _OfflineActivityError extends StatelessWidget {
  const _OfflineActivityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.error_outline,
            color: colors.error,
            size: 40,
            semanticLabel: AppStrings.offlineActivityLoadError,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.offlineActivityLoadError,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: AppStrings.retry,
            icon: Icons.refresh_outlined,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
