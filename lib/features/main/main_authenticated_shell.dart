import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../high_level_categories/high_level_categories_screen.dart';
import '../profile/profile_screen.dart';
import '../ranking/ranking_screen.dart';

enum MainSection { home, ranking, profile }

class MainAuthenticatedShell extends StatefulWidget {
  const MainAuthenticatedShell({
    required this.authRepository,
    required this.userProfile,
    required this.personalTotalPoints,
    required this.userProfileRepository,
    required this.leaderboardRepository,
    required this.onProfileChanged,
    required this.contentRepository,
    required this.progressController,
    required this.user,
    super.key,
  });

  final AuthUser user;
  final AuthRepository authRepository;
  final UserProfile userProfile;
  final int? personalTotalPoints;
  final UserProfileRepository userProfileRepository;
  final LeaderboardRepository leaderboardRepository;
  final ValueChanged<UserProfile> onProfileChanged;
  final ContentRepository contentRepository;
  final CategoryProgressController progressController;

  @override
  State<MainAuthenticatedShell> createState() => _MainAuthenticatedShellState();
}

class _MainAuthenticatedShellState extends State<MainAuthenticatedShell> {
  MainSection _selectedSection = MainSection.home;
  bool _isNavigationVisible = true;

  void _selectSection(MainSection section) {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;
    });
  }

  void _toggleNavigation() {
    setState(() {
      _isNavigationVisible = !_isNavigationVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: switch (_selectedSection) {
        MainSection.home => HighLevelCategoriesScreen(
          authRepository: widget.authRepository,
          userProfile: widget.userProfile,
          personalTotalPoints: widget.personalTotalPoints,
          userProfileRepository: widget.userProfileRepository,
          onProfileChanged: widget.onProfileChanged,
          showBackButton: false,
        ),
        MainSection.ranking => RankingScreen(
          user: widget.user,
          profile: widget.userProfile,
          totalPoints:
              widget.personalTotalPoints ?? widget.userProfile.totalPoints,
          leaderboardRepository: widget.leaderboardRepository,
        ),
        MainSection.profile => ProfileScreen(
          user: widget.user,
          profile: widget.userProfile,
          personalTotalPoints: widget.personalTotalPoints,
          authRepository: widget.authRepository,
          userProfileRepository: widget.userProfileRepository,
          contentRepository: widget.contentRepository,
          progressController: widget.progressController,
          onProfileChanged: widget.onProfileChanged,
        ),
      },
      bottomNavigationBar: _CollapsibleMainNavigation(
        selectedSection: _selectedSection,
        isVisible: _isNavigationVisible,
        onToggleVisibility: _toggleNavigation,
        onSectionSelected: _selectSection,
      ),
    );
  }
}

class _CollapsibleMainNavigation extends StatelessWidget {
  const _CollapsibleMainNavigation({
    required this.selectedSection,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onSectionSelected,
  });

  final MainSection selectedSection;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final ValueChanged<MainSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toggleLabel = isVisible
        ? AppStrings.hideNavigation
        : AppStrings.showNavigation;
    final toggleButton = _NavigationToggleButton(
      tooltip: toggleLabel,
      isVisible: isVisible,
      onPressed: onToggleVisibility,
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isVisible
              ? Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceStrong,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadii.card),
                          ),
                          border: Border(top: BorderSide(color: colors.border)),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xs,
                            AppSpacing.md,
                            AppSpacing.xs,
                            AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              _MainNavButton(
                                key: const Key('main_nav_home'),
                                icon: Icons.home_outlined,
                                selectedIcon: Icons.home,
                                label: AppStrings.homeTitle,
                                selected: selectedSection == MainSection.home,
                                onTap: () =>
                                    onSectionSelected(MainSection.home),
                              ),
                              _MainNavButton(
                                key: const Key('main_nav_ranking'),
                                icon: Icons.leaderboard_outlined,
                                selectedIcon: Icons.leaderboard,
                                label: AppStrings.rankingTitle,
                                selected:
                                    selectedSection == MainSection.ranking,
                                onTap: () =>
                                    onSectionSelected(MainSection.ranking),
                              ),
                              _MainNavButton(
                                key: const Key('main_nav_profile'),
                                icon: Icons.person_outline,
                                selectedIcon: Icons.person,
                                label: AppStrings.profileTitle,
                                selected:
                                    selectedSection == MainSection.profile,
                                onTap: () =>
                                    onSectionSelected(MainSection.profile),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: 0, child: toggleButton),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    AppSpacing.xxs,
                    0,
                    AppSpacing.xs,
                  ),
                  child: SizedBox(
                    height: 36,
                    child: Center(child: toggleButton),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NavigationToggleButton extends StatelessWidget {
  const _NavigationToggleButton({
    required this.tooltip,
    required this.isVisible,
    required this.onPressed,
  });

  final String tooltip;
  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          key: const Key('main_nav_toggle'),
          color: colors.surfaceStrong,
          elevation: 3,
          shadowColor: colors.textPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 46,
              height: 32,
              child: Icon(
                isVisible
                    ? Icons.keyboard_arrow_down_outlined
                    : Icons.keyboard_arrow_up_outlined,
                color: colors.orangePrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavButton extends StatelessWidget {
  const _MainNavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = colors.orangeDark;
    final inactiveColor = colors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? activeColor : inactiveColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
