import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../shared/feedback/app_dialog.dart';
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                _HeaderSidePanel(
                  objectives: category.objectives,
                  progress: progress,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSidePanel extends StatelessWidget {
  const _HeaderSidePanel({required this.objectives, required this.progress});

  final List<String> objectives;
  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _ObjectivesButton(objectives: objectives),
          ),
          Expanded(
            child: Center(
              child: const CharacterImage(
                assetPath: AppAssets.girlMenu,
                semanticLabel: 'Personaje explorando opciones',
                height: AppSizing.characterInlineHeight,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: _ProgressPill(progress: progress),
          ),
        ],
      ),
    );
  }
}

class _ObjectivesButton extends StatefulWidget {
  const _ObjectivesButton({required this.objectives});

  final List<String> objectives;

  @override
  State<_ObjectivesButton> createState() => _ObjectivesButtonState();
}

class _ObjectivesButtonState extends State<_ObjectivesButton>
    with SingleTickerProviderStateMixin {
  static const _infoBlue = Color(0xFF1565C0);
  static const _infoHighlight = Color(0xFF90CAF9);

  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shineController.stop();
      return;
    }
    if (!_shineController.isAnimating && !_shineController.isCompleted) {
      _shineController.forward();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => AppDialog.showContent(
        context,
        title: AppStrings.objectivesTitle,
        icon: Icons.checklist_outlined,
        closeLabel: AppStrings.close,
        content: _ObjectivesCard(objectives: widget.objectives),
      ),
      icon: _ShiningInfoIcon(animation: _shineController),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSizing.minTouchTarget,
        height: AppSizing.minTouchTarget,
      ),
      color: _infoBlue,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSizing.minTouchTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _infoBlue,
        overlayColor: _infoHighlight.withValues(alpha: 0.18),
      ),
      tooltip: AppStrings.viewObjectives,
    );
  }
}

class _ShiningInfoIcon extends StatelessWidget {
  const _ShiningInfoIcon({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const icon = Icons.info_outline;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox.square(
      dimension: AppSizing.minTouchTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(icon, color: _ObjectivesButtonState._infoBlue, size: 30),
          if (!reduceMotion)
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    final offset = bounds.width * ((animation.value * 2) - 0.5);
                    return const LinearGradient(
                      colors: [
                        Colors.transparent,
                        _ObjectivesButtonState._infoHighlight,
                        Colors.white,
                        _ObjectivesButtonState._infoHighlight,
                        Colors.transparent,
                      ],
                      stops: [0, 0.42, 0.5, 0.58, 1],
                    ).createShader(
                      Rect.fromLTWH(
                        offset - bounds.width,
                        0,
                        bounds.width,
                        bounds.height,
                      ),
                    );
                  },
                  child: child,
                );
              },
              child: const Icon(icon, color: Colors.white, size: 30),
            ),
        ],
      ),
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
