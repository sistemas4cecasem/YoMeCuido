import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/quiz_question.dart';
import '../../data/models/quiz_result.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/answer_option_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/feedback_card.dart';
import '../../shared/widgets/lesson_progress_bar.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/result_summary_card.dart';
import '../../shared/widgets/secondary_button.dart';
import 'quiz_controller.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.category,
    required this.contentRepository,
    super.key,
  });

  final Category category;
  final ContentRepository contentRepository;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget.contentRepository.loadQuizQuestions(
      widget.category.id,
    );
  }

  void _retry() {
    setState(() {
      _questionsFuture = widget.contentRepository.loadQuizQuestions(
        widget.category.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.quizTitle,
      child: FutureBuilder<List<QuizQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.length != QuizController.expectedQuestionCount) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Quiz load error: ${snapshot.error}');
            }
            return _QuizLoadError(onRetry: _retry);
          }

          return _QuizFlow(questions: snapshot.data!);
        },
      ),
    );
  }
}

class _QuizFlow extends StatefulWidget {
  const _QuizFlow({required this.questions});

  final List<QuizQuestion> questions;

  @override
  State<_QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends State<_QuizFlow> {
  late final QuizController _controller;
  final TextEditingController _answerTextController = TextEditingController();
  bool _allowPop = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = QuizController(questions: widget.questions);
  }

  @override
  void dispose() {
    _controller.dispose();
    _answerTextController.dispose();
    super.dispose();
  }

  Future<void> _handleBackIntent() async {
    if (_controller.answeredQuestions == 0) {
      _popQuizRoute();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.exitLessonTitle),
        content: const Text(AppStrings.exitLessonBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.keepLearning),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.exit),
          ),
        ],
      ),
    );

    if (mounted && shouldExit == true) {
      _popQuizRoute();
    }
  }

  void _popQuizRoute() {
    setState(() {
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _submitAnswer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _controller.submitAnswer();
  }

  void _goForward() {
    if (_controller.isLastActivity) {
      setState(() {
        _showResult = true;
      });
      return;
    }

    _answerTextController.clear();
    _controller.goToNextActivity();
  }

  void _repeatLesson() {
    _answerTextController.clear();
    setState(() {
      _showResult = false;
    });
    _controller.reset();
  }

  void _backToCategories() {
    Navigator.of(context).popUntil((route) {
      return route.settings.name == AppRoutes.categories || route.isFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackIntent();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_showResult) {
            return _ResultView(
              result: _controller.generateResult(),
              onRepeatLesson: _repeatLesson,
              onBackToCategories: _backToCategories,
            );
          }

          return _ActivityView(
            controller: _controller,
            answerTextController: _answerTextController,
            onSubmitAnswer: _submitAnswer,
            onGoForward: _goForward,
          );
        },
      ),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView({
    required this.controller,
    required this.answerTextController,
    required this.onSubmitAnswer,
    required this.onGoForward,
  });

  final QuizController controller;
  final TextEditingController answerTextController;
  final VoidCallback onSubmitAnswer;
  final VoidCallback onGoForward;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad ${controller.currentActivityNumber} de '
          '${controller.totalQuestions}',
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        LessonProgressBar(
          currentStep: controller.currentActivityNumber,
          totalSteps: controller.totalQuestions,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: AppSpacing.md + bottomInset),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  controller.currentStatement,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                _AnswerInput(
                  controller: controller,
                  textController: answerTextController,
                ),
                if (controller.isAnswerConfirmed) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FeedbackCard(
                    isCorrect: controller.isCurrentAnswerCorrect ?? false,
                    feedback: controller.currentFeedback ?? '',
                    expectedAnswer: controller.isCurrentAnswerCorrect == false
                        ? controller.currentCorrectAnswerText
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.isAnswerConfirmed)
          PrimaryButton(
            label: controller.isLastActivity
                ? AppStrings.seeResult
                : AppStrings.nextActivity,
            icon: controller.isLastActivity
                ? Icons.assessment_outlined
                : Icons.arrow_forward_outlined,
            onPressed: onGoForward,
          )
        else
          PrimaryButton(
            label: AppStrings.submitAnswer,
            icon: Icons.check_outlined,
            onPressed: controller.canSubmitAnswer ? onSubmitAnswer : null,
          ),
      ],
    );
  }
}

class _AnswerInput extends StatelessWidget {
  const _AnswerInput({required this.controller, required this.textController});

  final QuizController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return switch (controller.currentQuestionType) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _ChoiceOptions(controller: controller),
      QuestionType.fillBlank => _FillBlankInput(
        controller: controller,
        textController: textController,
      ),
    };
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in controller.currentOptions) ...[
          AnswerOptionTile(
            text: option.text,
            isSelected: controller.selectedOptionId == option.id,
            onTap: controller.isAnswerConfirmed
                ? null
                : () => controller.selectOption(option.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _FillBlankInput extends StatelessWidget {
  const _FillBlankInput({
    required this.controller,
    required this.textController,
  });

  final QuizController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TextField(
      controller: textController,
      enabled: !controller.isAnswerConfirmed,
      maxLength: 32,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        LengthLimitingTextInputFormatter(32),
        FilteringTextInputFormatter.deny(RegExp(r'\s{2,}')),
      ],
      decoration: InputDecoration(
        labelText: AppStrings.fillBlankHint,
        counterText: '',
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: palette.purple, width: 2),
        ),
      ),
      onChanged: controller.updateWrittenAnswer,
      onSubmitted: (_) {
        if (controller.canSubmitAnswer) {
          FocusManager.instance.primaryFocus?.unfocus();
          controller.submitAnswer();
        }
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onRepeatLesson,
    required this.onBackToCategories,
  });

  final QuizResult result;
  final VoidCallback onRepeatLesson;
  final VoidCallback onBackToCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: ResultSummaryCard(result: result),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: AppStrings.repeatLesson,
          icon: Icons.refresh_outlined,
          onPressed: onRepeatLesson,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.backToCategories,
          icon: Icons.list_alt_outlined,
          onPressed: onBackToCategories,
        ),
      ],
    );
  }
}

class _QuizLoadError extends StatelessWidget {
  const _QuizLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.contentLoadError,
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
      ),
    );
  }
}
