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
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PersonalPointsCard(totalPoints: currentTotalPoints),
                        const SizedBox(height: AppSpacing.md),
                        _AccountInfoCard(role: _profile.role),
                        const SizedBox(height: AppSpacing.md),
                        _ProgressSection(
                          categoriesFuture: _categoriesFuture,
                          progressController: widget.progressController,
                          onRetry: _retryCategories,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _UsernameEditorCard(
                          user: widget.user,
                          profile: _profile,
                          authRepository: widget.authRepository,
                          userProfileRepository: widget.userProfileRepository,
                          onChanged: _handleProfileChanged,
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
  });

  final String username;
  final String email;
  final bool isEmailVerified;

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
            Text(
              username,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.manage_accounts_outlined,
              title: AppStrings.accountInfoTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
              label: AppStrings.profileRole,
              value: role == UserProfileRole.user
                  ? AppStrings.profileUserRole
                  : role,
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
    required this.onRetry,
  });

  final Future<List<Category>> categoriesFuture;
  final CategoryProgressController progressController;
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

                return Column(
                  children: [
                    for (var index = 0; index < categories.length; index += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == categories.length - 1
                              ? 0
                              : AppSpacing.sm,
                        ),
                        child: _CategoryProgressCard(
                          category: categories[index],
                          progress: progressController.snapshotFor(
                            categories[index].id,
                          ),
                        ),
                      ),
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
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: '${progress.overallPercentage} por ciento',
                    child: LinearProgressIndicator(
                      value: progress.overallProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: colors.orangeSoft,
                      color: progress.overallPercentage == 0
                          ? colors.orangeDark
                          : colors.success,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${progress.overallPercentage}%',
                  style: textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${progress.completedActivities} / '
              '${progress.totalActivities} actividades completadas',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${progress.viewedTheoryPages} / '
              '${progress.totalTheoryPages} cápsulas vistas',
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

class _UsernameEditorCard extends StatelessWidget {
  const _UsernameEditorCard({
    required this.user,
    required this.profile,
    required this.authRepository,
    required this.userProfileRepository,
    required this.onChanged,
  });

  final AuthUser user;
  final UserProfile profile;
  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.edit_outlined,
              title: AppStrings.editUsernameTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileUsernameEditor(
              uid: user.uid,
              profile: profile,
              authRepository: authRepository,
              repository: userProfileRepository,
              onChanged: onChanged,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
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
