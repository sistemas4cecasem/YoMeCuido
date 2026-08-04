import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    required this.isCorrect,
    required this.feedback,
    this.expectedAnswer,
    super.key,
  });

  final bool isCorrect;
  final String feedback;
  final String? expectedAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = isCorrect ? colors.success : colors.error;
    final statusText = isCorrect ? AppStrings.correct : AppStrings.reviewAnswer;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    statusText,
                    style: textTheme.titleSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(feedback, style: textTheme.bodyLarge),
            if (!isCorrect && expectedAnswer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${AppStrings.expectedAnswer}: $expectedAnswer',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
