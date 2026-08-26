import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/learning_activity.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/character_image.dart';

class ActivitiesMenuScreen extends StatefulWidget {
  const ActivitiesMenuScreen({
    required this.category,
    required this.contentRepository,
    required this.progressController,
    super.key,
  });

  final Category category;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;

  @override
  State<ActivitiesMenuScreen> createState() => _ActivitiesMenuScreenState();
}

class _ActivitiesMenuScreenState extends State<ActivitiesMenuScreen> {
  late Future<_ActivitiesMenuData> _menuDataFuture;

  @override
  void initState() {
    super.initState();
    _menuDataFuture = _loadMenuData();
  }

  void _retry() {
    setState(() {
      _menuDataFuture = _loadMenuData();
    });
  }

  Future<_ActivitiesMenuData> _loadMenuData() async {
    final activities = await widget.contentRepository.loadActivities(
      widget.category.id,
    );
    final sortedActivities = activities.toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    final questionCounts = <String, int>{};

    for (final activity in sortedActivities) {
      final questions = await widget.contentRepository.loadQuizQuestions(
        widget.category.id,
        activityId: activity.id,
      );
      questionCounts[activity.id] = questions.length;
    }

    return _ActivitiesMenuData(
      activities: sortedActivities,
      questionCountsByActivityId: questionCounts,
    );
  }

  void _openQuiz(LearningActivity activity) {
    Navigator.of(context).pushNamed(
      AppRoutes.quiz,
      arguments: QuizRouteArguments(
        category: widget.category,
        activity: activity,
      ),
    );
  }

  void _showLockedMessage() {
    AppToast.showInfo(context, AppStrings.demoLockedSnackBar);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.activitiesTitle,
      child: FutureBuilder<_ActivitiesMenuData>(
        future: _menuDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.activities.isEmpty) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Activities load error: ${snapshot.error}');
            }
            return _ActivitiesLoadError(onRetry: _retry);
          }

          final menuData = snapshot.data!;

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
                    _IntroCard(totalActivities: menuData.activities.length),
                    const SizedBox(height: AppSpacing.lg),
                    for (final activity in menuData.activities) ...[
                      _ActivityBlockCard(
                        title: activity.title,
                        subtitle: menuData.questionCountFor(activity.id) > 0
                            ? '${menuData.questionCountFor(activity.id)} preguntas'
                            : AppStrings.comingSoon,
                        progressLabel:
                            menuData.questionCountFor(activity.id) > 0
                            ? '${progress.completedActivities} de '
                                  '${menuData.questionCountFor(activity.id)} '
                                  'completadas'
                            : null,
                        icon: menuData.questionCountFor(activity.id) > 0
                            ? Icons.workspace_premium_outlined
                            : Icons.lock_outline,
                        unlocked: menuData.questionCountFor(activity.id) > 0,
                        completed:
                            menuData.questionCountFor(activity.id) > 0 &&
                            progress.completedActivities >=
                                menuData.questionCountFor(activity.id),
                        onTap: menuData.questionCountFor(activity.id) > 0
                            ? () => _openQuiz(activity)
                            : _showLockedMessage,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.totalActivities});

  final int totalActivities;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.activityMenuIntroTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.activityMenuIntroBody,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SmallInfoPill(label: '$totalActivities actividades'),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const CharacterImage(
              assetPath: AppAssets.boyStart,
              semanticLabel: 'Personaje listo para iniciar actividades',
              height: AppSizing.characterInlineHeight,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitiesMenuData {
  const _ActivitiesMenuData({
    required this.activities,
    required this.questionCountsByActivityId,
  });

  final List<LearningActivity> activities;
  final Map<String, int> questionCountsByActivityId;

  int questionCountFor(String activityId) {
    return questionCountsByActivityId[activityId] ?? 0;
  }
}

class _ActivityBlockCard extends StatelessWidget {
  const _ActivityBlockCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
    required this.onTap,
    this.progressLabel,
    this.completed = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
  final bool completed;
  final String? progressLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final foregroundColor = unlocked ? colors.textPrimary : colors.disabledText;
    final accentColor = completed ? colors.success : colors.orangeDark;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      button: true,
      enabled: unlocked,
      label: unlocked ? title : '$title, ${AppStrings.locked}',
      child: Card(
        color: unlocked ? colors.surface : colors.disabledSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: unlocked ? colors.orangePrimary : colors.border,
            width: unlocked ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useVerticalLayout =
                  constraints.maxWidth < 300 || textScale > 1.3;
              final showTrailingIcon =
                  constraints.maxWidth >= 300 && textScale <= 1.3;
              final leadingIcon = Container(
                width: AppSizing.minTouchTarget,
                height: AppSizing.minTouchTarget,
                decoration: BoxDecoration(
                  color: unlocked ? colors.orangeSoft : colors.disabledSurface,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: unlocked ? colors.orangePrimary : colors.border,
                  ),
                ),
                child: Icon(
                  completed ? Icons.check_outlined : icon,
                  color: unlocked ? accentColor : colors.disabledText,
                ),
              );
              final textContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    progressLabel ?? subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: unlocked
                          ? colors.textSecondary
                          : colors.disabledText,
                    ),
                  ),
                ],
              );

              return Padding(
                padding: AppInsets.card,
                child: useVerticalLayout
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leadingIcon,
                          const SizedBox(height: AppSpacing.sm),
                          textContent,
                        ],
                      )
                    : Row(
                        children: [
                          leadingIcon,
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: textContent),
                          if (showTrailingIcon) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              unlocked
                                  ? Icons.chevron_right_outlined
                                  : Icons.lock_outline,
                              color: unlocked
                                  ? colors.orangeDark
                                  : colors.disabledText,
                            ),
                          ],
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SmallInfoPill extends StatelessWidget {
  const _SmallInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.orangeSoft,
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

class _ActivitiesLoadError extends StatelessWidget {
  const _ActivitiesLoadError({required this.onRetry});

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
