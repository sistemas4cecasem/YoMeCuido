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
import '../quiz/activity_question_selector.dart';

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
    widget.progressController.updateActivityTotal(
      categoryId: widget.category.id,
      totalActivities: sortedActivities.length,
    );
    final questions = await widget.contentRepository.loadQuizQuestions(
      widget.category.id,
    );
    final questionCounts = const ActivityQuestionSelector()
        .countQuestionsByActivity(
          questions: questions,
          categoryId: widget.category.id,
          activities: sortedActivities,
        );
    return _ActivitiesMenuData(
      activities: sortedActivities,
      questionCountsByActivityId: questionCounts,
    );
  }

  void _openQuiz(LearningActivity activity, int totalActivities) {
    Navigator.of(context).pushNamed(
      AppRoutes.quiz,
      arguments: QuizRouteArguments.activity(
        category: widget.category,
        activity: activity,
        totalActivities: totalActivities,
      ),
    );
  }

  void _showLockedMessage([String message = AppStrings.demoLockedSnackBar]) {
    AppToast.showInfo(context, message);
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
                    for (
                      var index = 0;
                      index < menuData.activities.length;
                      index += 1
                    )
                      _ActivityBlock(
                        activity: menuData.activities[index],
                        unlocked: _isActivityUnlocked(
                          index,
                          menuData.activities,
                          progress,
                        ),
                        menuData: menuData,
                        progress: progress,
                        onOpen: (activity) {
                          _openQuiz(activity, menuData.activities.length);
                        },
                        onLocked: () => _showLockedMessage(
                          progress.hasCompletedTheory
                              ? AppStrings.completePreviousActivity
                              : AppStrings.completeTheoryToUnlockActivities,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isActivityUnlocked(
    int index,
    List<LearningActivity> activities,
    CategoryProgressSnapshot progress,
  ) {
    if (!progress.hasCompletedTheory) {
      return false;
    }

    if (index == 0) {
      return true;
    }

    return progress.activityPassed(activities[index].id) ||
        progress.activityPassed(activities[index - 1].id);
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

class _ActivityBlock extends StatelessWidget {
  const _ActivityBlock({
    required this.activity,
    required this.unlocked,
    required this.menuData,
    required this.progress,
    required this.onOpen,
    required this.onLocked,
  });

  final LearningActivity activity;
  final bool unlocked;
  final _ActivitiesMenuData menuData;
  final CategoryProgressSnapshot progress;
  final ValueChanged<LearningActivity> onOpen;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final questionCount = menuData.questionCountFor(activity.id);
    final hasQuestions = questionCount > 0;
    final activityProgress = progress.activityProgress[activity.id];
    final completed = activityProgress?.isPassed == true;
    final needsRetry =
        activityProgress?.isCompleted == true &&
        activityProgress?.isPassed != true;
    final attempts = activityProgress?.attemptCount ?? 0;
    final progressLabel = !unlocked || !hasQuestions
        ? null
        : completed
        ? 'Completada'
        : needsRetry
        ? 'Reintentar'
        : attempts > 0
        ? 'Intento iniciado'
        : 'Pendiente';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _ActivityBlockCard(
        title: activity.title,
        subtitle: unlocked && hasQuestions
            ? '$questionCount preguntas'
            : AppStrings.locked,
        progressLabel: progressLabel,
        icon: unlocked && hasQuestions
            ? Icons.workspace_premium_outlined
            : Icons.lock_outline,
        unlocked: unlocked && hasQuestions,
        completed: completed,
        onTap: unlocked && hasQuestions ? () => onOpen(activity) : onLocked,
      ),
    );
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
    final completedSurface = Color.alphaBlend(
      colors.success.withValues(alpha: 0.05),
      colors.surface,
    );
    final completedIconSurface = Color.alphaBlend(
      colors.success.withValues(alpha: 0.08),
      colors.surfaceStrong,
    );
    final cardColor = !unlocked
        ? colors.disabledSurface
        : completed
        ? completedSurface
        : colors.surface;
    final borderColor = !unlocked
        ? colors.border
        : completed
        ? colors.success.withValues(alpha: 0.55)
        : colors.orangePrimary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      button: true,
      enabled: unlocked,
      label: unlocked ? title : '$title, ${AppStrings.locked}',
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: borderColor, width: unlocked ? 1.5 : 1),
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
                  color: !unlocked
                      ? colors.disabledSurface
                      : completed
                      ? completedIconSurface
                      : colors.orangeSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: borderColor),
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
                      color: !unlocked
                          ? colors.disabledText
                          : completed
                          ? colors.success
                          : colors.textSecondary,
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
                          if (showTrailingIcon && !completed) ...[
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
