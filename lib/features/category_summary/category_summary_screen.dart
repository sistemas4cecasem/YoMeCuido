import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/character_image.dart';

class CategorySummaryScreen extends StatefulWidget {
  const CategorySummaryScreen({
    required this.category,
    required this.contentRepository,
    required this.progressController,
    super.key,
  });

  final Category category;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;

  @override
  State<CategorySummaryScreen> createState() => _CategorySummaryScreenState();
}

class _CategorySummaryScreenState extends State<CategorySummaryScreen> {
  late Future<void> _contentTotalsFuture;

  @override
  void initState() {
    super.initState();
    _contentTotalsFuture = _syncContentTotals();
  }

  Future<void> _syncContentTotals() async {
    final lessonPages = await widget.contentRepository.loadLessonPages(
      widget.category.id,
    );
    final activities = await widget.contentRepository.loadActivities(
      widget.category.id,
    );
    widget.progressController.updateTheoryTotal(
      categoryId: widget.category.id,
      totalPages: lessonPages.length,
    );
    widget.progressController.updateActivityTotal(
      categoryId: widget.category.id,
      totalActivities: activities.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.category.title,
      child: FutureBuilder<void>(
        future: _contentTotalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _CategorySummaryLoadError(onRetry: _retry);
          }

          return AnimatedBuilder(
            animation: widget.progressController,
            builder: (context, child) {
              final progress = widget.progressController.snapshotFor(
                widget.category.id,
              );

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverallProgressCard(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _ProgressStats(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _PerformanceCard(progress: progress),
                    const SizedBox(height: AppSpacing.md),
                    _EncouragementCard(progress: progress),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _retry() {
    setState(() {
      _contentTotalsFuture = _syncContentTotals();
    });
  }
}

class _CategorySummaryLoadError extends StatelessWidget {
  const _CategorySummaryLoadError({required this.onRetry});

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
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.categoryProgress, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        '${progress.overallPercentage} por ciento de progreso',
                    child: LinearProgressIndicator(
                      value: progress.overallProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: colors.orangeSoft,
                      color: colors.success,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${progress.overallPercentage}%',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Avance validado por teoría, actividades aprobadas y examen.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${progress.viewedTheoryPages} de ${progress.totalTheoryPages} cápsulas vistas'
              ' · '
              '${progress.passedActivities} de ${progress.totalActivities} actividades aprobadas',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStats extends StatelessWidget {
  const _ProgressStats({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final shouldStack = MediaQuery.sizeOf(context).width < 360;

    final theoryCard = _StatCard(
      icon: Icons.menu_book_outlined,
      label: AppStrings.theoryTitle,
      value: '${progress.viewedTheoryPages} / ${progress.totalTheoryPages}',
      caption: AppStrings.completedPlural,
    );
    final activityCard = _StatCard(
      icon: Icons.edit_outlined,
      label: AppStrings.activitiesTitle,
      value: '${progress.passedActivities} / ${progress.totalActivities}',
      caption: 'Aprobadas',
    );

    if (shouldStack) {
      return Column(
        children: [
          theoryCard,
          const SizedBox(height: AppSpacing.sm),
          activityCard,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: theoryCard),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: activityCard),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final attemptCount = _attemptCount(progress);
    final bestResult = _bestResult(progress);
    final metrics = [
      _PerformanceMetricData(
        value: '${progress.earnedPoints} pts',
        label: 'Puntaje',
      ),
      _PerformanceMetricData(value: '$attemptCount', label: 'Intentos'),
      _PerformanceMetricData(
        value: bestResult == null ? '—' : '$bestResult%',
        label: 'Mejor resultado',
      ),
    ];

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu rendimiento', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 320) {
                  return Column(
                    children: [
                      for (var index = 0; index < metrics.length; index += 1)
                        Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : AppSpacing.sm,
                          ),
                          child: _PerformanceMetric(
                            data: metrics[index],
                            alignment: CrossAxisAlignment.start,
                          ),
                        ),
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var index = 0; index < metrics.length; index += 1) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _PerformanceMetric(data: metrics[index])),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _attemptCount(CategoryProgressSnapshot progress) {
    return progress.activityProgress.values.fold<int>(
          0,
          (total, activity) => total + activity.attemptCount,
        ) +
        progress.examProgress.values.fold<int>(
          0,
          (total, exam) => total + exam.attemptCount,
        );
  }

  int? _bestResult(CategoryProgressSnapshot progress) {
    final percentages = <int>[
      for (final activity in progress.activityProgress.values)
        if (activity.attemptCount > 0) activity.bestPercentage,
      for (final exam in progress.examProgress.values)
        if (exam.attemptCount > 0) exam.bestPercentage,
    ];

    if (percentages.isEmpty) {
      return null;
    }

    return percentages.reduce((best, value) => value > best ? value : best);
  }
}

class _PerformanceMetricData {
  const _PerformanceMetricData({required this.value, required this.label});

  final String value;
  final String label;
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({
    required this.data,
    this.alignment = CrossAxisAlignment.center,
  });

  final _PerformanceMetricData data;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final textAlign = alignment == CrossAxisAlignment.center
        ? TextAlign.center
        : TextAlign.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: textTheme.titleMedium?.copyWith(color: colors.success),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.surface,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.orangeDark, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(color: colors.success),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              caption,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncouragementCard extends StatelessWidget {
  const _EncouragementCard({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final state = progress.subcategoryCompleted
        ? const _EncouragementState(
            title: 'Subcategoría completada',
            message:
                'Completaste la teoría, aprobaste las actividades y aprobaste el examen final.',
            assetPath: AppAssets.girlCompleted,
          )
        : progress.hasCompletedTheory
        ? const _EncouragementState(
            title: 'En progreso',
            message:
                'Continúa con las actividades aprobadas y el examen final para completar la subcategoría.',
            assetPath: AppAssets.girlProgress,
          )
        : const _EncouragementState(
            title: 'En progreso',
            message:
                'Continúa aprendiendo y practicando para fortalecer tus decisiones de autocuidado.',
            assetPath: AppAssets.girlProgress,
          );

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          children: [
            CharacterImage(
              assetPath: state.assetPath,
              semanticLabel: 'Personaje mostrando avance',
              height: AppSizing.characterInlineHeight,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.title, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(state.message, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _ExamStatus(progress: progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncouragementState {
  const _EncouragementState({
    required this.title,
    required this.message,
    required this.assetPath,
  });

  final String title;
  final String message;
  final String assetPath;
}

class _ExamStatus extends StatelessWidget {
  const _ExamStatus({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final exam = _bestExamProgress;
    final status = progress.hasPassedExam
        ? 'Aprobado'
        : exam == null
        ? progress.examUnlocked
              ? 'Disponible'
              : 'Bloqueado'
        : 'No aprobado / Reintentar';
    final bestText = exam == null
        ? null
        : 'Mejor resultado: ${exam.bestPercentage}%';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              progress.hasPassedExam
                  ? Icons.check_circle_outline
                  : progress.examUnlocked
                  ? Icons.fact_check_outlined
                  : Icons.lock_outline,
              color: progress.hasPassedExam
                  ? colors.success
                  : progress.examUnlocked
                  ? colors.orangeDark
                  : colors.disabledText,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                bestText == null
                    ? 'Examen final: $status'
                    : 'Examen final: $status · $bestText',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ExamProgressSnapshot? get _bestExamProgress {
    ExamProgressSnapshot? best;
    for (final exam in progress.examProgress.values) {
      if (exam.attemptCount == 0) {
        continue;
      }
      if (best == null || exam.bestPercentage > best.bestPercentage) {
        best = exam;
      }
    }
    return best;
  }
}
