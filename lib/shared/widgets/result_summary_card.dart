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
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${result.correctAnswers} de ${result.totalQuestions} respuestas correctas',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${result.percentage}%', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
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
