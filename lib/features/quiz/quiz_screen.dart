import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_assets.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/quiz_question.dart';
import '../../data/models/quiz_result.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_dialog.dart';
import '../../shared/widgets/answer_option_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/character_image.dart';
import '../../shared/widgets/lesson_progress_bar.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/result_summary_card.dart';
import '../../shared/widgets/secondary_button.dart';
import 'quiz_controller.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.category,
    required this.contentRepository,
    required this.progressController,
    super.key,
  });

  final Category category;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizQuestion>> _questionsFuture;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget.contentRepository.loadQuizQuestions(
      widget.category.id,
    );
  }

  void _retry() {
    setState(() {
      _showingResult = false;
      _questionsFuture = widget.contentRepository.loadQuizQuestions(
        widget.category.id,
      );
    });
  }

  void _handleResultVisibilityChanged(bool isVisible) {
    if (_showingResult == isVisible) {
      return;
    }

    setState(() {
      _showingResult = isVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.quizTitle,
      automaticallyImplyLeading: !_showingResult,
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

          return _QuizFlow(
            category: widget.category,
            questions: snapshot.data!,
            progressController: widget.progressController,
            onResultVisibilityChanged: _handleResultVisibilityChanged,
          );
        },
      ),
    );
  }
}

class _QuizFlow extends StatefulWidget {
  const _QuizFlow({
    required this.category,
    required this.questions,
    required this.progressController,
    required this.onResultVisibilityChanged,
  });

  final Category category;
  final List<QuizQuestion> questions;
  final CategoryProgressController progressController;
  final ValueChanged<bool> onResultVisibilityChanged;

  @override
  State<_QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends State<_QuizFlow> {
  late final QuizController _controller;
  final TextEditingController _answerTextController = TextEditingController();
  final math.Random _characterRandom = math.Random();
  final Map<String, _ActivityCharacter> _activityCharacters =
      <String, _ActivityCharacter>{};
  bool _allowPop = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = QuizController(questions: widget.questions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        widget.progressController.startActivityAttempt(
          categoryId: widget.category.id,
          lessonId: widget.category.lessonId ?? widget.category.id,
          totalActivities: widget.questions.length,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _answerTextController.dispose();
    super.dispose();
  }

  Future<void> _handleBackIntent() async {
    if (_showResult) {
      return;
    }

    if (_controller.answeredQuestions == 0) {
      _popQuizRoute();
      return;
    }

    final shouldExit = await AppDialog.showConfirmation(
      context,
      title: AppStrings.exitLessonTitle,
      message: AppStrings.exitLessonBody,
      cancelLabel: AppStrings.keepLearning,
      confirmLabel: AppStrings.exit,
      icon: Icons.logout_outlined,
      isDestructiveConfirm: true,
    );

    if (mounted && shouldExit) {
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
    final activityId = _controller.currentQuestionId;
    final answer = _currentAnswerForPersistence();
    final submitted = _controller.submitAnswer();
    if (!submitted) {
      return;
    }

    unawaited(
      widget.progressController.recordActivityAnswer(
        categoryId: widget.category.id,
        lessonId: widget.category.lessonId ?? widget.category.id,
        activityId: activityId,
        answer: answer,
        isCorrect: _controller.isCurrentAnswerCorrect ?? false,
        correctAnswers: _controller.correctAnswers,
        totalActivities: _controller.totalQuestions,
        result: _controller.isFinished ? _controller.quizResult : null,
      ),
    );
  }

  String _currentAnswerForPersistence() {
    return switch (_controller.currentQuestionType) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _controller.selectedOptionId ?? '',
      QuestionType.fillBlank => _controller.writtenAnswer.trim(),
    };
  }

  void _goForward() {
    if (_controller.isLastActivity) {
      setState(() {
        _showResult = true;
      });
      widget.onResultVisibilityChanged(true);
      return;
    }

    _answerTextController.clear();
    _controller.goToNextActivity();
  }

  void _repeatLesson() {
    _answerTextController.clear();
    _activityCharacters.clear();
    _controller.reset();
    widget.progressController.resetCategory(widget.category.id);
    unawaited(
      widget.progressController.startActivityAttempt(
        categoryId: widget.category.id,
        lessonId: widget.category.lessonId ?? widget.category.id,
        totalActivities: widget.questions.length,
      ),
    );
    setState(() {
      _allowPop = false;
      _showResult = false;
    });
    widget.onResultVisibilityChanged(false);
  }

  void _backToActivities() {
    setState(() {
      _allowPop = true;
    });
    widget.onResultVisibilityChanged(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    });
  }

  _ActivityCharacter _characterForCurrentActivity() {
    return _activityCharacters.putIfAbsent(
      _controller.currentQuestionId,
      () => _characterRandom.nextBool()
          ? _ActivityCharacter.girl
          : _ActivityCharacter.boy,
    );
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
              onBackToActivities: _backToActivities,
              onRepeatLesson: _repeatLesson,
            );
          }

          return _ActivityView(
            controller: _controller,
            activityCharacter: _characterForCurrentActivity(),
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
    required this.activityCharacter,
    required this.answerTextController,
    required this.onSubmitAnswer,
    required this.onGoForward,
  });

  final QuizController controller;
  final _ActivityCharacter activityCharacter;
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
                _ActivityIllustration(
                  controller: controller,
                  activityCharacter: activityCharacter,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  controller.currentStatement,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                _AnswerInput(
                  controller: controller,
                  textController: answerTextController,
                  onSubmitAnswer: onSubmitAnswer,
                ),
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
        else if (controller.canSubmitAnswer)
          Align(
            alignment: Alignment.centerRight,
            child: _CompactSubmitButton(onPressed: onSubmitAnswer),
          ),
      ],
    );
  }
}

class _CompactSubmitButton extends StatelessWidget {
  const _CompactSubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.submitAnswer,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_outlined),
        label: const Text(AppStrings.submitAnswer),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}

class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.controller,
    required this.textController,
    required this.onSubmitAnswer,
  });

  final QuizController controller;
  final TextEditingController textController;
  final VoidCallback onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
    return switch (controller.currentQuestionType) {
      QuestionType.multipleChoice ||
      QuestionType.trueFalse => _ChoiceOptions(controller: controller),
      QuestionType.fillBlank => _FillBlankInput(
        controller: controller,
        textController: textController,
        onSubmitAnswer: onSubmitAnswer,
      ),
    };
  }
}

class _ActivityIllustration extends StatelessWidget {
  const _ActivityIllustration({
    required this.controller,
    required this.activityCharacter,
  });

  final QuizController controller;
  final _ActivityCharacter activityCharacter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final assetPath = _assetForState(controller);
    final titleText = _titleTextForState(controller);
    final bodyText = _bodyTextForState(controller);

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalLayout =
                constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35;
            final characterWidth = (constraints.maxWidth - 150).clamp(
              140.0,
              190.0,
            );
            const horizontalImageHeight = AppSizing.characterFeatureHeight;
            const verticalImageHeight = AppSizing.characterInlineHeight;
            final image = AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: CharacterImage(
                key: ValueKey(assetPath),
                assetPath: assetPath,
                semanticLabel: '$titleText. $bodyText',
                height: useVerticalLayout
                    ? verticalImageHeight
                    : horizontalImageHeight,
              ),
            );
            final illustratedState = Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                image,
                if (!reduceMotion &&
                    controller.isAnswerConfirmed &&
                    controller.isCurrentAnswerCorrect == true)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _CorrectConfetti(
                        key: ValueKey(controller.currentQuestionId),
                      ),
                    ),
                  ),
              ],
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconForState(controller),
                      color: _colorForState(colors),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        titleText,
                        style: textTheme.titleSmall?.copyWith(
                          color: controller.isAnswerConfirmed
                              ? _colorForState(colors)
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  bodyText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            );
            final constrainedIllustration = SizedBox(
              width: characterWidth,
              height: horizontalImageHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                child: illustratedState,
              ),
            );

            if (useVerticalLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: SizedBox(
                      height: verticalImageHeight,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: illustratedState,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: content),
                const SizedBox(width: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: constrainedIllustration,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _assetForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      if (controller.isCurrentAnswerCorrect == true) {
        return activityCharacter.correctAsset;
      }

      return activityCharacter.incorrectAsset;
    }

    return activityCharacter.normalAsset;
  }

  String _titleTextForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      if (controller.isCurrentAnswerCorrect == true) {
        return AppStrings.correct;
      }

      return AppStrings.reviewAnswer;
    }

    return 'Antes de responder';
  }

  String _bodyTextForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      return controller.currentFeedback ?? '';
    }

    if (controller.currentQuestionType == QuestionType.fillBlank) {
      return 'Piensa en una palabra breve y concreta.';
    }

    return 'Lee la situación y elige la respuesta más segura.';
  }

  IconData _iconForState(QuizController controller) {
    if (controller.isAnswerConfirmed) {
      return controller.isCurrentAnswerCorrect == true
          ? Icons.check_circle_outline
          : Icons.cancel_outlined;
    }

    return controller.currentQuestionType == QuestionType.fillBlank
        ? Icons.lightbulb_outline
        : Icons.psychology_outlined;
  }

  Color _colorForState(AppColors colors) {
    if (!controller.isAnswerConfirmed) {
      return colors.orangeDark;
    }

    return controller.isCurrentAnswerCorrect == true
        ? colors.success
        : colors.error;
  }
}

enum _ActivityCharacter {
  boy(
    normalAsset: AppAssets.activityBoyNormal,
    correctAsset: AppAssets.activityBoyCorrect,
    incorrectAsset: AppAssets.activityBoyIncorrect,
  ),
  girl(
    normalAsset: AppAssets.activityGirlNormal,
    correctAsset: AppAssets.activityGirlCorrect,
    incorrectAsset: AppAssets.activityGirlIncorrect,
  );

  const _ActivityCharacter({
    required this.normalAsset,
    required this.correctAsset,
    required this.incorrectAsset,
  });

  final String normalAsset;
  final String correctAsset;
  final String incorrectAsset;
}

class _CorrectConfetti extends StatefulWidget {
  const _CorrectConfetti({super.key});

  @override
  State<_CorrectConfetti> createState() => _CorrectConfettiState();
}

class _CorrectConfettiState extends State<_CorrectConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = <Color>[
    Color(0xFFFF8A00),
    Color(0xFFFFC107),
    Color(0xFF2E7D32),
    Color(0xFF7B1FA2),
    Color(0xFF2196F3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.35);

    for (var index = 0; index < 18; index += 1) {
      final angle = (-130 + (index * 260 / 17)) * math.pi / 180;
      final distance = (32 + (index % 5) * 8) * eased;
      final drift = Offset(math.cos(angle), math.sin(angle)) * distance;
      final fall = Offset(0, 18 * progress * progress);
      final position = center + drift + fall;
      final paint = Paint()
        ..color = _colors[index % _colors.length].withValues(alpha: opacity);
      final width = 5.0 + (index % 3);
      final height = 9.0 + (index % 2) * 3.0;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final visibleOptions = controller.isAnswerConfirmed
        ? controller.currentOptions.where((option) {
            return option.id == controller.selectedOptionId;
          })
        : controller.currentOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in visibleOptions) ...[
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
    required this.onSubmitAnswer,
  });

  final QuizController controller;
  final TextEditingController textController;
  final VoidCallback onSubmitAnswer;

  @override
  Widget build(BuildContext context) {
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
      ),
      onChanged: controller.updateWrittenAnswer,
      onSubmitted: (_) {
        if (controller.canSubmitAnswer) {
          onSubmitAnswer();
        }
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onBackToActivities,
    required this.onRepeatLesson,
  });

  final QuizResult result;
  final VoidCallback onBackToActivities;
  final VoidCallback onRepeatLesson;

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
          label: AppStrings.backToActivities,
          icon: Icons.format_list_bulleted_outlined,
          onPressed: onBackToActivities,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.repeatLesson,
          icon: Icons.refresh_outlined,
          onPressed: onRepeatLesson,
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
