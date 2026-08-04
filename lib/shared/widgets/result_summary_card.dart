import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/quiz_result.dart';
import 'character_image.dart';

class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({required this.result, super.key});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultHero(result: result),
            const SizedBox(height: AppSpacing.lg),
            _MetricsPanel(result: result),
            const SizedBox(height: AppSpacing.lg),
            _ClosingMessageCard(
              message: result.closingMessage,
              level: result.level,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _RemindersPanel(),
          ],
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accentColor = _accentColorForResult(colors, result);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 300 || textScale > 1.3;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AchievementChip(
              color: accentColor,
              label: result.achievementLabel,
              icon: _chipIconForResult(result),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.lessonCompleted, style: textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.headlineMessage,
              style: textTheme.titleMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
        final character = CharacterImage(
          assetPath: _characterAssetForResult(result),
          semanticLabel: _characterSemanticLabelForResult(result),
          height: 184,
        );

        if (useVerticalLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.md),
              Center(child: character),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: heading),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: character),
            ),
          ],
        );
      },
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final needsPractice = result.totalQuestions - result.correctAnswers;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: AppInsets.card,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useStackedLayout = constraints.maxWidth < 520;
            final stats = [
              _MetricTile(
                icon: Icons.help_outline,
                iconColor: colors.orangePrimary,
                value: '${result.totalQuestions}',
                label: 'preguntas',
              ),
              _MetricTile(
                icon: Icons.check_circle_outline,
                iconColor: colors.success,
                value: '${result.correctAnswers}',
                label: 'correctas',
                highlight: true,
              ),
              _MetricTile(
                icon: Icons.refresh_outlined,
                iconColor: colors.orangeDark,
                value: '$needsPractice',
                label: 'por reforzar',
              ),
            ];

            if (useStackedLayout) {
              return Column(
                children: [
                  _ScoreRing(result: result),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      for (final stat in stats) ...[
                        Expanded(child: stat),
                        if (stat != stats.last)
                          const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 4, child: _ScoreRing(result: result)),
                const SizedBox(width: AppSpacing.md),
                for (final stat in stats) ...[
                  Expanded(flex: 3, child: stat),
                  if (stat != stats.last) const SizedBox(width: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final progress = result.correctAnswers / result.totalQuestions;

    return Semantics(
      label:
          '${result.correctAnswers} de ${result.totalQuestions} respuestas correctas. '
          '${result.percentage} por ciento.',
      child: SizedBox(
        width: 156,
        height: 156,
        child: CustomPaint(
          painter: _ScoreRingPainter(
            progress: progress,
            trackColor: colors.orangeSoft,
            progressColor: colors.orangePrimary,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
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
                    Text(
                      'respuestas correctas',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.12;
    final rect = Offset.zero & size;
    final insetRect = rect.deflate(strokeWidth / 2);
    final startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress.clamp(0.0, 1.0);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(insetRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(insetRect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight
            ? colors.success.withValues(alpha: 0.08)
            : colors.surfaceStrong,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: highlight
              ? colors.success.withValues(alpha: 0.28)
              : colors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingMessageCard extends StatelessWidget {
  const _ClosingMessageCard({required this.message, required this.level});

  final String message;
  final QuizResultLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = switch (level) {
      QuizResultLevel.high => colors.success,
      QuizResultLevel.medium => colors.orangeDark,
      QuizResultLevel.low => colors.error,
    };
    final icon = switch (level) {
      QuizResultLevel.high => Icons.star_outlined,
      QuizResultLevel.medium => Icons.trending_up_outlined,
      QuizResultLevel.low => Icons.refresh_outlined,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: accentColor.withValues(alpha: 0.14),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _accentColorForResult(AppColors colors, QuizResult result) {
  return switch (result.level) {
    QuizResultLevel.high => colors.success,
    QuizResultLevel.medium => colors.orangeDark,
    QuizResultLevel.low => colors.error,
  };
}

IconData _chipIconForResult(QuizResult result) {
  return switch (result.level) {
    QuizResultLevel.high => Icons.star_outlined,
    QuizResultLevel.medium => Icons.trending_up_outlined,
    QuizResultLevel.low => Icons.refresh_outlined,
  };
}

String _characterAssetForResult(QuizResult result) {
  return switch (result.characterAssetKey) {
    'boyCompleted' => AppAssets.boyCompleted,
    'girlProgress' => AppAssets.girlProgress,
    'boyThinking' => AppAssets.boyThinking,
    _ => AppAssets.boyThinking,
  };
}

String _characterSemanticLabelForResult(QuizResult result) {
  return switch (result.level) {
    QuizResultLevel.high => 'Personaje celebrando una actividad completada',
    QuizResultLevel.medium => 'Personaje mostrando avance de aprendizaje',
    QuizResultLevel.low =>
      'Personaje reflexionando sobre recomendaciones para reforzar',
  };
}

class _RemindersPanel extends StatelessWidget {
  const _RemindersPanel();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.remindersTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Reminder(text: AppStrings.reminderAccounts),
            Divider(color: colors.border),
            const _Reminder(text: AppStrings.reminderEvidence),
            Divider(color: colors.border),
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
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 24, color: colors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
