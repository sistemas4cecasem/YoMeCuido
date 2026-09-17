import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/quiz_result.dart';
import 'character_image.dart';

class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({
    required this.result,
    this.takeaways = const <String>[],
    this.earnedPoints,
    this.totalPoints,
    super.key,
  });

  final QuizResult result;
  final List<String> takeaways;
  final int? earnedPoints;
  final int? totalPoints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MainResultPanel(
          result: result,
          earnedPoints: earnedPoints,
          totalPoints: totalPoints,
        ),
        if (takeaways.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _TakeawaysPanel(takeaways: takeaways),
        ],
      ],
    );
  }
}

class _MainResultPanel extends StatelessWidget {
  const _MainResultPanel({
    required this.result,
    required this.earnedPoints,
    required this.totalPoints,
  });

  final QuizResult result;
  final int? earnedPoints;
  final int? totalPoints;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultHeader(result: result),
            const SizedBox(height: AppSpacing.md),
            Center(child: _ScoreRing(result: result)),
            const SizedBox(height: AppSpacing.md),
            Text(
              result.closingMessage,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (earnedPoints != null || totalPoints != null) ...[
              const SizedBox(height: AppSpacing.md),
              _CompactPointsSummary(
                earnedPoints: earnedPoints,
                totalPoints: totalPoints,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accentColor = _accentColorForResult(colors, result);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 320 || textScale > 1.3;
        final heading = _ResultHeading(
          result: result,
          accentColor: accentColor,
        );
        final character = CharacterImage(
          assetPath: _characterAssetForResult(result),
          semanticLabel: _characterSemanticLabelForResult(result),
          height: useVerticalLayout
              ? AppSizing.characterInlineHeight
              : AppSizing.characterFeatureHeight,
        );

        return useVerticalLayout
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: AppSpacing.sm),
                  Center(child: character),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: character,
                    ),
                  ),
                ],
              );
      },
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.result, required this.accentColor});

  final QuizResult result;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AchievementChip(
          color: accentColor,
          label: result.achievementLabel,
          icon: _chipIconForResult(result),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.lessonCompleted, style: textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.headlineMessage,
          style: textTheme.titleMedium?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
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

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final progress = result.progressFraction;

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
                      '${result.correctAnswers} de ${result.totalQuestions} correctas',
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall,
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

class _CompactPointsSummary extends StatelessWidget {
  const _CompactPointsSummary({
    required this.earnedPoints,
    required this.totalPoints,
  });

  final int? earnedPoints;
  final int? totalPoints;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = <Widget>[
      if (earnedPoints != null)
        _PointPill(
          icon: Icons.add_circle_outline,
          label: AppStrings.earnedPoints,
          value: _formatEarnedPoints(earnedPoints!),
          color: colors.orangeDark,
        ),
      if (totalPoints != null)
        _PointPill(
          icon: Icons.stacked_line_chart_outlined,
          label: AppStrings.totalPoints,
          value: _formatPoints(totalPoints!),
          color: colors.purpleSecondary,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.orangeSoft.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: items,
        ),
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  const _PointPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Wrap(
              spacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label.toLowerCase(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _TakeawaysPanel extends StatelessWidget {
  const _TakeawaysPanel({required this.takeaways});

  final List<String> takeaways;

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
              AppStrings.takeawaysTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < takeaways.length; index += 1) ...[
              _Reminder(text: takeaways[index]),
              if (index < takeaways.length - 1) Divider(color: colors.border),
            ],
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

String _formatEarnedPoints(int value) {
  if (value == 0) {
    return '0';
  }
  return '+${_formatPoints(value)}';
}

String _formatPoints(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index += 1) {
    final remaining = text.length - index;
    buffer.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
