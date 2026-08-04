import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/category_card.dart';
import '../../shared/widgets/character_image.dart';
import '../../shared/widgets/demo_bottom_navigation_bar.dart';
import '../../shared/widgets/info_card.dart';

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    required this.category,
    required this.progressController,
    super.key,
  });

  final Category category;
  final CategoryProgressController progressController;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: category.title,
      bottomNavigationBar: DemoBottomNavigationBar(category: category),
      child: AnimatedBuilder(
        animation: progressController,
        builder: (context, child) {
          final progress = progressController.snapshotFor(category.id);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(category: category, progress: progress),
                const SizedBox(height: AppSpacing.lg),
                _LearningRoute(
                  category: category,
                  progress: progress,
                  onOpenTheory: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.lesson, arguments: category),
                  onOpenActivities: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.activities, arguments: category),
                  onOpenSummary: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.categorySummary, arguments: category),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (category.warning != null)
                  InfoCard(
                    title: AppStrings.sensitiveContentWarningTitle,
                    body: category.warning!,
                    icon: Icons.info_outline,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category, required this.progress});

  final Category category;
  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final showSideContent = MediaQuery.textScalerOf(context).scale(1) <= 1.2;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppSizing.minTouchTarget,
                        height: AppSizing.minTouchTarget,
                        decoration: BoxDecoration(
                          color: colors.orangeSoft,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: colors.orangePrimary),
                        ),
                        child: Icon(
                          categoryIconFromName(category.iconName),
                          color: colors.orangeDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          category.title,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (!showSideContent) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _ObjectivesButton(objectives: category.objectives),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(category.description, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final indicator in category.indicators)
                        _IndicatorChip(label: indicator),
                    ],
                  ),
                ],
              ),
            ),
            if (showSideContent) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: _ObjectivesButton(objectives: category.objectives),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  const CharacterImage(
                    assetPath: AppAssets.girlMenu,
                    semanticLabel: 'Personaje explorando opciones',
                    height: 116,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ProgressPill(progress: progress),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ObjectivesButton extends StatelessWidget {
  const _ObjectivesButton({required this.objectives});

  final List<String> objectives;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IconButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _ObjectivesDialog(objectives: objectives),
      ),
      icon: const Icon(Icons.help_outline),
      color: colors.orangeDark,
      style: IconButton.styleFrom(
        backgroundColor: colors.orangeSoft,
        minimumSize: const Size.square(AppSizing.minTouchTarget),
        side: BorderSide(color: colors.orangePrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      tooltip: AppStrings.viewObjectives,
    );
  }
}

class _ObjectivesDialog extends StatelessWidget {
  const _ObjectivesDialog({required this.objectives});

  final List<String> objectives;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.objectivesTitle),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SingleChildScrollView(
        child: _ObjectivesCard(objectives: objectives),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.close),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.progress});

  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
        child: Column(
          children: [
            Text(
              'Tu progreso',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            Text(
              '${progress.overallPercentage}%',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningRoute extends StatelessWidget {
  const _LearningRoute({
    required this.category,
    required this.progress,
    required this.onOpenTheory,
    required this.onOpenActivities,
    required this.onOpenSummary,
  });

  final Category category;
  final CategoryProgressSnapshot progress;
  final VoidCallback onOpenTheory;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenSummary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.learningRouteTitle, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _RouteStepCard(
          number: 1,
          title: AppStrings.theoryTitle,
          subtitle:
              '${progress.viewedTheoryPages} de '
              '${progress.totalTheoryPages} cápsulas vistas',
          icon: Icons.menu_book_outlined,
          completed: progress.hasCompletedTheory,
          onTap: onOpenTheory,
        ),
        const SizedBox(height: AppSpacing.sm),
        _RouteStepCard(
          number: 2,
          title: AppStrings.activitiesTitle,
          subtitle:
              '${progress.completedActivities} de '
              '${progress.totalActivities} actividades completadas',
          icon: Icons.edit_outlined,
          completed: progress.hasCompletedActivities,
          onTap: onOpenActivities,
        ),
        const SizedBox(height: AppSpacing.sm),
        _RouteStepCard(
          number: 3,
          title: AppStrings.summaryTitle,
          subtitle: 'Consulta tu avance y el resultado de la categoría',
          icon: Icons.insights_outlined,
          completed: progress.hasResult,
          onTap: onOpenSummary,
        ),
      ],
    );
  }
}

class _RouteStepCard extends StatelessWidget {
  const _RouteStepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    required this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Card(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalLayout =
                constraints.maxWidth < 300 || textScale > 1.3;
            final showTrailingIcon =
                constraints.maxWidth >= 300 && textScale <= 1.3;
            final stepBadge = CircleAvatar(
              radius: 20,
              backgroundColor: completed
                  ? colors.success.withValues(alpha: 0.12)
                  : colors.orangePrimary,
              child: completed
                  ? Icon(Icons.check_outlined, color: colors.success)
                  : Text(
                      '$number',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.surfaceStrong,
                      ),
                    ),
            );
            final textContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: colors.orangeDark),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            );

            return Padding(
              padding: AppInsets.card,
              child: useVerticalLayout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        stepBadge,
                        const SizedBox(height: AppSpacing.sm),
                        textContent,
                      ],
                    )
                  : Row(
                      children: [
                        stepBadge,
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: textContent),
                        if (showTrailingIcon) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.chevron_right_outlined,
                            color: colors.orangeDark,
                          ),
                        ],
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _ObjectivesCard extends StatelessWidget {
  const _ObjectivesCard({required this.objectives});

  final List<String> objectives;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          children: [
            for (final objective in objectives) ...[
              _ObjectiveRow(text: objective),
              if (objective != objectives.last)
                Divider(height: AppSpacing.lg, color: colors.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: colors.success, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
