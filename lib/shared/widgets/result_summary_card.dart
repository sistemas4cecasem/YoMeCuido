import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/quiz_result.dart';

class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({required this.result, super.key});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: palette.purple, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.lessonCompleted, style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            Center(child: _ScoreProgress(result: result)),
            const SizedBox(height: AppSpacing.lg),
            Text(result.closingMessage, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.remindersTitle, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            const _Reminder(text: AppStrings.reminderAccounts),
            const _Reminder(text: AppStrings.reminderEvidence),
            const _Reminder(text: AppStrings.reminderSupport),
          ],
        ),
      ),
    );
  }
}

class _ScoreProgress extends StatelessWidget {
  const _ScoreProgress({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final progress = result.correctAnswers / result.totalQuestions;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final usesLargeText = textScale > 1.3;

    return Semantics(
      label:
          '${result.correctAnswers} de ${result.totalQuestions} respuestas correctas. '
          '${result.percentage} por ciento.',
      child: usesLargeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${result.percentage}%',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${result.correctAnswers} de ${result.totalQuestions} '
                  'respuestas correctas',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: palette.border,
                  color: palette.purple,
                ),
              ],
            )
          : SizedBox(
              width: 164,
              height: 164,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: palette.border,
                      color: palette.purple,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result.percentage}%',
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${result.correctAnswers} de ${result.totalQuestions}',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'respuestas correctas',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _Reminder extends StatelessWidget {
  const _Reminder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_outlined, size: 20, color: palette.success),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
