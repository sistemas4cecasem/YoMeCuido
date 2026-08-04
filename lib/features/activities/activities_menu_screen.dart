import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_assets.dart';
import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/quiz_question.dart';
import '../../data/repositories/content_repository.dart';
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
  late Future<List<QuizQuestion>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture = widget.contentRepository.loadQuizQuestions(
      widget.category.id,
    );
  }

  void _retry() {
    setState(() {
      _questionsFuture = widget.contentRepository.loadQuizQuestions(
        widget.category.id,
      );
    });
  }

  void _openQuiz() {
    Navigator.of(context).pushNamed(AppRoutes.quiz, arguments: widget.category);
  }

  void _showLockedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.demoLockedSnackBar)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.activitiesTitle,
      child: FutureBuilder<List<QuizQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            if (kDebugMode && snapshot.error != null) {
              debugPrint('Activities load error: ${snapshot.error}');
            }
            return _ActivitiesLoadError(onRetry: _retry);
          }

          final totalQuestions = snapshot.data!.length;

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
                    _IntroCard(totalQuestions: totalQuestions),
                    const SizedBox(height: AppSpacing.lg),
                    _ActivityBlockCard(
                      title: AppStrings.firstActivityBlock,
                      subtitle: '$totalQuestions actividades',
                      progressLabel:
                          '${progress.completedActivities} de '
                          '$totalQuestions completadas',
                      icon: Icons.workspace_premium_outlined,
                      unlocked: true,
                      completed: progress.completedActivities >= totalQuestions,
                      onTap: _openQuiz,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ActivityBlockCard(
                      title: AppStrings.secondActivityBlock,
                      subtitle: '$totalQuestions actividades',
                      icon: Icons.lock_outline,
                      unlocked: false,
                      onTap: _showLockedMessage,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ActivityBlockCard(
                      title: AppStrings.thirdActivityBlock,
                      subtitle: '$totalQuestions actividades',
                      icon: Icons.lock_outline,
                      unlocked: false,
                      onTap: _showLockedMessage,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ActivityBlockCard(
                      title: AppStrings.finalActivityBlock,
                      subtitle: AppStrings.finalActivitySubtitle,
                      icon: Icons.emoji_events_outlined,
                      unlocked: false,
                      onTap: _showLockedMessage,
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
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.totalQuestions});

  final int totalQuestions;

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
                  _SmallInfoPill(label: '$totalQuestions actividades'),
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
