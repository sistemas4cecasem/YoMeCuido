import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/category.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../shared/feedback/app_dialog.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_background.dart';
import '../auth/profile_username_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.profile,
    required this.personalTotalPoints,
    required this.authRepository,
    required this.userProfileRepository,
    required this.contentRepository,
    required this.progressController,
    required this.onProfileChanged,
    super.key,
  });

  final AuthUser user;
  final UserProfile profile;
  final int? personalTotalPoints;
  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;
  final ValueChanged<UserProfile> onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _profile = widget.profile;
  late Future<List<Category>> _categoriesFuture = _loadCategories();
  bool _isSigningOut = false;
  String? _selectedProgressParentCategoryId;

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
    }
    if (oldWidget.contentRepository != widget.contentRepository) {
      _categoriesFuture = _loadCategories();
    }
  }

  Future<List<Category>> _loadCategories() async {
    final categories = await widget.contentRepository.loadCategories();
    return categories.where((category) => category.isEnabled).toList();
  }

  void _retryCategories() {
    setState(() {
      _categoriesFuture = _loadCategories();
    });
  }

  void _handleProfileChanged(UserProfile profile) {
    setState(() {
      _profile = profile;
    });
    widget.onProfileChanged(profile);
  }

  void _showUsernameEditor() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screen,
            right: AppSpacing.screen,
            top: AppSpacing.lg,
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom +
                AppSpacing.screen,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(
                icon: Icons.edit_outlined,
                title: AppStrings.editUsernameTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              ProfileUsernameEditor(
                uid: widget.user.uid,
                profile: _profile,
                authRepository: widget.authRepository,
                repository: widget.userProfileRepository,
                onChanged: (profile) {
                  _handleProfileChanged(profile);
                  Navigator.of(sheetContext).pop();
                },
                startEditing: true,
                onCancel: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) {
      return;
    }

    final shouldSignOut = await AppDialog.showConfirmation(
      context,
      title: AppStrings.signOutTitle,
      message: AppStrings.signOutBody,
      cancelLabel: AppStrings.cancel,
      confirmLabel: AppStrings.signOut,
      icon: Icons.logout_outlined,
      isDestructiveConfirm: true,
    );

    if (!mounted || !shouldSignOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await widget.authRepository.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.showError(context, AppStrings.signOutError);
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final email = _profile.email.isNotEmpty
        ? _profile.email
        : widget.user.email ?? '-';
    final totalPoints =
        widget.progressController.totalPointsForUser(widget.user.uid) ??
        widget.personalTotalPoints ??
        _profile.totalPoints;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: AppBackground(
          child: AnimatedBuilder(
            animation: widget.progressController,
            builder: (context, child) {
              final currentTotalPoints =
                  widget.progressController.totalPointsForUser(
                    widget.user.uid,
                  ) ??
                  totalPoints;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizing.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppStrings.myProfileTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ProfileHeader(
                          username: _profile.username ?? '-',
                          email: email,
                          isEmailVerified: widget.user.isEmailVerified,
                          onEditUsername: _showUsernameEditor,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PersonalPointsCard(totalPoints: currentTotalPoints),
                        const SizedBox(height: AppSpacing.md),
                        _ProgressSection(
                          categoriesFuture: _categoriesFuture,
                          progressController: widget.progressController,
                          selectedParentCategoryId:
                              _selectedProgressParentCategoryId,
                          onParentCategorySelected: (parentCategoryId) {
                            setState(() {
                              _selectedProgressParentCategoryId =
                                  parentCategoryId;
                            });
                          },
                          onRetry: _retryCategories,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SignOutCard(
                          isSigningOut: _isSigningOut,
                          onSignOut: _confirmAndSignOut,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.email,
    required this.isEmailVerified,
    required this.onEditUsername,
  });

  final String username;
  final String email;
  final bool isEmailVerified;
  final VoidCallback onEditUsername;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final trimmedUsername = username.trim();
    final initial = trimmedUsername.isEmpty || trimmedUsername == '-'
        ? '?'
        : trimmedUsername.substring(0, 1).toUpperCase();

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.orangeSoft,
              foregroundColor: colors.orangeDark,
              child: Text(
                initial,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.orangeDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CenteredEditableUsername(
              username: username,
              onEditUsername: onEditUsername,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              email,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _VerifiedStatus(isVerified: isEmailVerified),
          ],
        ),
      ),
    );
  }
}

class _VerifiedStatus extends StatelessWidget {
  const _VerifiedStatus({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVerified ? Icons.verified_user_outlined : Icons.error_outline,
          color: isVerified ? colors.success : colors.error,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isVerified
              ? AppStrings.profileVerifiedEmail
              : AppStrings.profileUnverifiedEmail,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CenteredEditableUsername extends StatelessWidget {
  const _CenteredEditableUsername({
    required this.username,
    required this.onEditUsername,
  });

  final String username;
  final VoidCallback onEditUsername;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTextWidth =
            (constraints.maxWidth - AppSizing.minTouchTarget - AppSpacing.xs)
                .clamp(0.0, constraints.maxWidth);
        final textWidth = _measureTextWidth(
          text: username,
          style: textStyle,
          maxWidth: maxTextWidth,
          textScaler: MediaQuery.textScalerOf(context),
        );
        final iconLeft =
            (constraints.maxWidth / 2) + (textWidth / 2) + AppSpacing.xxs;
        final clampedIconLeft = iconLeft.clamp(
          0.0,
          constraints.maxWidth - AppSizing.minTouchTarget,
        );

        return SizedBox(
          height: AppSizing.minTouchTarget,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              ),
              Positioned(
                left: clampedIconLeft,
                top: 0,
                bottom: 0,
                child: IconButton(
                  tooltip: AppStrings.changeUsername,
                  onPressed: onEditUsername,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonalPointsCard extends StatelessWidget {
  const _PersonalPointsCard({required this.totalPoints});

  final int totalPoints;

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
            _IconBox(icon: Icons.workspace_premium_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.profileTotalPoints,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _formatPoints(totalPoints),
                    style: textTheme.headlineSmall?.copyWith(
                      color: colors.orangeDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.categoriesFuture,
    required this.progressController,
    required this.selectedParentCategoryId,
    required this.onParentCategorySelected,
    required this.onRetry,
  });

  final Future<List<Category>> categoriesFuture;
  final CategoryProgressController progressController;
  final String? selectedParentCategoryId;
  final ValueChanged<String?> onParentCategorySelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.insights_outlined,
              title: AppStrings.myProgressTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<Category>>(
              future: categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _InlineLoadError(onRetry: onRetry);
                }

                final categories = snapshot.data!;
                if (categories.isEmpty) {
                  return const Text(AppStrings.noProgressCategories);
                }

                final progressByCategory = {
                  for (final category in categories)
                    category.id: progressController.snapshotFor(category.id),
                };
                final summary = _ProgressSummary.fromSnapshots(
                  progressByCategory.values,
                );
                final filters = _ParentCategoryProgressFilter.fromCategories(
                  categories,
                );
                final selectedFilter = filters
                    .where((filter) => filter.id == selectedParentCategoryId)
                    .firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverallProgressCard(summary: summary),
                    const SizedBox(height: AppSpacing.md),
                    _ParentCategoryFilterMenu(
                      filters: filters,
                      selectedFilter: selectedFilter,
                      onSelected: onParentCategorySelected,
                      onClear: selectedFilter == null
                          ? null
                          : () => onParentCategorySelected(null),
                    ),
                    if (selectedFilter != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.profileCategoryBreakdown,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (
                        var index = 0;
                        index < selectedFilter.categories.length;
                        index += 1
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == selectedFilter.categories.length - 1
                                ? 0
                                : AppSpacing.sm,
                          ),
                          child: _CategoryProgressCard(
                            category: selectedFilter.categories[index],
                            progress:
                                progressByCategory[selectedFilter
                                    .categories[index]
                                    .id]!,
                          ),
                        ),
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
}

class _ProgressSummary {
  const _ProgressSummary({
    required this.percentage,
    required this.completedActivities,
    required this.totalActivities,
    required this.viewedTheoryPages,
    required this.totalTheoryPages,
  });

  factory _ProgressSummary.fromSnapshots(
    Iterable<CategoryProgressSnapshot> snapshots,
  ) {
    var completedActivities = 0;
    var totalActivities = 0;
    var viewedTheoryPages = 0;
    var totalTheoryPages = 0;

    for (final snapshot in snapshots) {
      completedActivities += snapshot.completedActivities;
      totalActivities += snapshot.totalActivities;
      viewedTheoryPages += snapshot.viewedTheoryPages;
      totalTheoryPages += snapshot.totalTheoryPages;
    }

    final totalSteps = totalActivities + totalTheoryPages;
    final completedSteps = completedActivities + viewedTheoryPages;
    final percentage = totalSteps == 0
        ? 0
        : ((completedSteps / totalSteps) * 100).round().clamp(0, 100);

    return _ProgressSummary(
      percentage: percentage,
      completedActivities: completedActivities,
      totalActivities: totalActivities,
      viewedTheoryPages: viewedTheoryPages,
      totalTheoryPages: totalTheoryPages,
    );
  }

  final int percentage;
  final int completedActivities;
  final int totalActivities;
  final int viewedTheoryPages;
  final int totalTheoryPages;
}

class _ParentCategoryProgressFilter {
  const _ParentCategoryProgressFilter({
    required this.id,
    required this.title,
    required this.categories,
  });

  factory _ParentCategoryProgressFilter._fromGroup({
    required String id,
    required List<Category> categories,
  }) {
    return _ParentCategoryProgressFilter(
      id: id,
      title: _parentCategoryTitle(id),
      categories: List<Category>.unmodifiable(categories),
    );
  }

  static List<_ParentCategoryProgressFilter> fromCategories(
    List<Category> categories,
  ) {
    final categoriesByParent = <String, List<Category>>{};
    for (final category in categories) {
      categoriesByParent
          .putIfAbsent(category.parentCategoryId, () => <Category>[])
          .add(category);
    }

    final orderedParentIds = <String>[
      ParentCategoryIds.humanTrafficking,
      ParentCategoryIds.digitalSecurity,
      ...categoriesByParent.keys.where((id) {
        return id != ParentCategoryIds.humanTrafficking &&
            id != ParentCategoryIds.digitalSecurity;
      }),
    ];

    return [
      for (final parentId in orderedParentIds)
        if (categoriesByParent[parentId]?.isNotEmpty ?? false)
          _ParentCategoryProgressFilter._fromGroup(
            id: parentId,
            categories: categoriesByParent[parentId]!,
          ),
    ];
  }

  final String id;
  final String title;
  final List<Category> categories;
}

class _ParentCategoryFilterMenu extends StatelessWidget {
  const _ParentCategoryFilterMenu({
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
    required this.onClear,
  });

  final List<_ParentCategoryProgressFilter> filters;
  final _ParentCategoryProgressFilter? selectedFilter;
  final ValueChanged<String?> onSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final selected = selectedFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.profileChooseCategory,
          style: textTheme.labelSmall?.copyWith(
            color: colors.orangeDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        PopupMenuButton<String>(
          tooltip: AppStrings.profileChooseCategoryHint,
          initialValue: selected?.id,
          onSelected: onSelected,
          position: PopupMenuPosition.under,
          elevation: 3,
          color: colors.surfaceStrong,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: colors.border),
          ),
          itemBuilder: (context) {
            return [
              for (final filter in filters)
                PopupMenuItem(
                  value: filter.id,
                  child: Text(
                    filter.title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: filter.id == selected?.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ];
          },
          child: _ParentCategoryFilterField(
            label: selected?.title ?? AppStrings.profileChooseCategoryHint,
            isSelected: selected != null,
            onClear: onClear,
          ),
        ),
      ],
    );
  }
}

class _ParentCategoryFilterField extends StatelessWidget {
  const _ParentCategoryFilterField({
    required this.label,
    required this.isSelected,
    required this.onClear,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: AppStrings.profileChooseCategory,
      value: label,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppSizing.primaryButtonHeight,
        ),
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceStrong,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: isSelected ? colors.orangePrimary : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              color: isSelected ? colors.orangeDark : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (onClear != null)
              Tooltip(
                message: AppStrings.profileClearCategoryFilter,
                child: IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_outlined),
                  color: colors.orangeDark,
                  constraints: const BoxConstraints.tightFor(
                    width: AppSizing.minTouchTarget,
                    height: AppSizing.minTouchTarget,
                  ),
                ),
              )
            else
              const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_outlined,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.summary});

  final _ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

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
              AppStrings.profileOverallProgress,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProgressBar(percentage: summary.percentage),
            const SizedBox(height: AppSpacing.sm),
            _ProgressLine(
              icon: Icons.menu_book_outlined,
              label: AppStrings.profileTheoryProgress,
              value:
                  '${summary.viewedTheoryPages} / '
                  '${summary.totalTheoryPages}',
            ),
            const SizedBox(height: AppSpacing.xs),
            _ProgressLine(
              icon: Icons.task_alt_outlined,
              label: AppStrings.profileActivitiesProgress,
              value:
                  '${summary.completedActivities} / '
                  '${summary.totalActivities}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: '$percentage por ciento',
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: colors.orangeSoft,
              color: percentage == 0 ? colors.orangeDark : colors.success,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$percentage%', style: textTheme.titleSmall),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: colors.orangeDark, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CategoryProgressCard extends StatelessWidget {
  const _CategoryProgressCard({required this.category, required this.progress});

  final Category category;
  final CategoryProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

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
              category.title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProgressBar(percentage: progress.overallPercentage),
            const SizedBox(height: AppSpacing.sm),
            _ProgressLine(
              icon: Icons.task_alt_outlined,
              label: AppStrings.profileActivitiesProgress,
              value:
                  '${progress.completedActivities} / '
                  '${progress.totalActivities}',
            ),
            const SizedBox(height: AppSpacing.xs),
            _ProgressLine(
              icon: Icons.menu_book_outlined,
              label: AppStrings.profileTheoryProgress,
              value:
                  '${progress.viewedTheoryPages} / '
                  '${progress.totalTheoryPages}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({required this.isSigningOut, required this.onSignOut});

  final bool isSigningOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: OutlinedButton.icon(
          onPressed: isSigningOut ? null : onSignOut,
          icon: isSigningOut
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_outlined),
          label: const Text(AppStrings.signOut),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error),
            minimumSize: const Size.fromHeight(AppSizing.primaryButtonHeight),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Icon(icon, color: colors.orangeDark),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: AppSizing.minTouchTarget,
      height: AppSizing.minTouchTarget,
      decoration: BoxDecoration(
        color: colors.orangeSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.orangePrimary),
      ),
      child: Icon(icon, color: colors.orangeDark),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(AppStrings.contentLoadError),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text(AppStrings.retry),
        ),
      ],
    );
  }
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

String _parentCategoryTitle(String parentCategoryId) {
  return switch (parentCategoryId) {
    ParentCategoryIds.humanTrafficking => AppStrings.traffickingTitle,
    ParentCategoryIds.digitalSecurity => AppStrings.digitalSecurityTitle,
    _ => parentCategoryId,
  };
}

double _measureTextWidth({
  required String text,
  required TextStyle? style,
  required double maxWidth,
  required TextScaler textScaler,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
  return painter.size.width;
}
