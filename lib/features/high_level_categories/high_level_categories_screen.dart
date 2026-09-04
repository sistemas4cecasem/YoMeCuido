import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../auth/profile_username_editor.dart';
import '../../shared/feedback/app_dialog.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_background.dart';

class HighLevelCategoriesScreen extends StatelessWidget {
  const HighLevelCategoriesScreen({
    this.authRepository,
    this.userProfile,
    this.userProfileRepository,
    this.onProfileChanged,
    this.showBackButton = true,
    super.key,
  });

  final AuthRepository? authRepository;
  final UserProfile? userProfile;
  final UserProfileRepository? userProfileRepository;
  final ValueChanged<UserProfile>? onProfileChanged;
  final bool showBackButton;

  void _openDigitalSecurity(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.categories);
  }

  void _showTraffickingLocked(BuildContext context) {
    AppToast.showInfo(context, AppStrings.comingSoonSnackBar);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: AppBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xs,
                  AppSpacing.screen,
                  0,
                ),
                child: SizedBox(
                  height: AppSizing.minTouchTarget,
                  child: Row(
                    children: [
                      if (showBackButton)
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_outlined),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          constraints: const BoxConstraints.tightFor(
                            width: AppSizing.minTouchTarget,
                            height: AppSizing.minTouchTarget,
                          ),
                        )
                      else if (authRepository != null)
                        _UserAccountMenu(
                          authRepository: authRepository!,
                          userProfile: userProfile,
                          userProfileRepository: userProfileRepository,
                          onProfileChanged: onProfileChanged,
                        )
                      else
                        const SizedBox(width: AppSizing.minTouchTarget),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            AppSpacing.md,
                            AppSpacing.screen,
                            AppSpacing.lg,
                          ),
                          child: Center(
                            child: _CenteredCategoryButtons(
                              onTraffickingTap: () =>
                                  _showTraffickingLocked(context),
                              onDigitalSecurityTap: () =>
                                  _openDigitalSecurity(context),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UserMenuAction { profile, signOut }

class _UserAccountMenu extends StatefulWidget {
  const _UserAccountMenu({
    required this.authRepository,
    required this.userProfile,
    required this.userProfileRepository,
    required this.onProfileChanged,
  });

  final AuthRepository authRepository;
  final UserProfile? userProfile;
  final UserProfileRepository? userProfileRepository;
  final ValueChanged<UserProfile>? onProfileChanged;

  @override
  State<_UserAccountMenu> createState() => _UserAccountMenuState();
}

class _UserAccountMenuState extends State<_UserAccountMenu> {
  bool _isSigningOut = false;

  Future<void> _handleAction(_UserMenuAction action) async {
    switch (action) {
      case _UserMenuAction.profile:
        await _showProfile();
      case _UserMenuAction.signOut:
        await _confirmAndSignOut();
    }
  }

  Future<void> _showProfile() {
    final user = widget.authRepository.currentUser;

    return AppDialog.showContent(
      context,
      title: AppStrings.profileTitle,
      icon: Icons.person_outline,
      closeLabel: AppStrings.close,
      content: _ProfileDetails(
        user: user,
        profile: widget.userProfile,
        usernameEditor:
            user != null &&
                widget.userProfile != null &&
                widget.userProfileRepository != null &&
                widget.onProfileChanged != null
            ? ProfileUsernameEditor(
                uid: user.uid,
                profile: widget.userProfile!,
                authRepository: widget.authRepository,
                repository: widget.userProfileRepository!,
                onChanged: widget.onProfileChanged!,
              )
            : null,
      ),
    );
  }

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    final shouldSignOut = await AppDialog.showConfirmation(
      context,
      title: AppStrings.signOutTitle,
      message: AppStrings.signOutBody,
      cancelLabel: AppStrings.cancel,
      confirmLabel: AppStrings.signOut,
      icon: Icons.logout_outlined,
      isDestructiveConfirm: true,
    );

    if (!mounted) {
      return;
    }

    if (!shouldSignOut) {
      setState(() {
        _isSigningOut = false;
      });
      return;
    }

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
    return PopupMenuButton<_UserMenuAction>(
      tooltip: AppStrings.profileTitle,
      enabled: !_isSigningOut,
      icon: _isSigningOut
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.person_outline),
      constraints: const BoxConstraints(minWidth: 220),
      onSelected: _handleAction,
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _UserMenuAction.profile,
            child: _UserMenuItem(
              icon: Icons.account_circle_outlined,
              label: AppStrings.viewProfile,
            ),
          ),
          PopupMenuItem(
            value: _UserMenuAction.signOut,
            child: _UserMenuItem(
              icon: Icons.logout_outlined,
              label: AppStrings.signOut,
            ),
          ),
        ];
      },
    );
  }
}

class _UserMenuItem extends StatelessWidget {
  const _UserMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({
    required this.user,
    required this.profile,
    this.usernameEditor,
  });

  final AuthUser? user;
  final UserProfile? profile;
  final Widget? usernameEditor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final username = profile?.username ?? '-';
    final email = profile?.email ?? user?.email ?? '-';
    final role = profile?.role == UserProfileRole.user
        ? AppStrings.profileUserRole
        : profile?.role ?? '-';
    final verified = user?.isEmailVerified == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        usernameEditor ??
            _ProfileField(label: AppStrings.profileUsername, value: username),
        const SizedBox(height: AppSpacing.md),
        _ProfileField(label: AppStrings.profileEmail, value: email),
        const SizedBox(height: AppSpacing.md),
        _ProfileField(label: AppStrings.profileRole, value: role),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(
              verified ? Icons.verified_user_outlined : Icons.error_outline,
              color: verified ? colors.success : colors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                verified
                    ? AppStrings.profileVerifiedEmail
                    : AppStrings.profileUnverifiedEmail,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CenteredCategoryButtons extends StatelessWidget {
  const _CenteredCategoryButtons({
    required this.onTraffickingTap,
    required this.onDigitalSecurityTap,
  });

  final VoidCallback onTraffickingTap;
  final VoidCallback onDigitalSecurityTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizing.maxContentWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HighLevelCategoryCard(
              title: AppStrings.traffickingTitle,
              icon: Icons.lock_outline_rounded,
              enabled: false,
              onTap: onTraffickingTap,
            ),
            const SizedBox(height: AppSpacing.lg),
            _HighLevelCategoryCard(
              title: AppStrings.digitalSecurityTitle,
              description: AppStrings.digitalSecurityDescription,
              icon: Icons.shield_outlined,
              enabled: true,
              onTap: onDigitalSecurityTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighLevelCategoryCard extends StatelessWidget {
  const _HighLevelCategoryCard({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.description,
  });

  final String title;
  final String? description;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final foregroundColor = enabled ? colors.textPrimary : colors.disabledText;
    final secondaryColor = enabled ? colors.textSecondary : colors.disabledText;
    final cardColor = enabled ? colors.surfaceStrong : colors.disabledSurface;
    final iconBackground = enabled ? colors.orangeSoft : colors.background;
    final borderColor = enabled ? colors.orangePrimary : colors.border;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = textScale > 1.25;
    final cardHeight = compact ? 164.0 : 152.0;
    final iconSize = compact ? 58.0 : 68.0;
    final padding = compact ? AppSpacing.md : AppSpacing.lg;

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? title : '$title, ${AppStrings.comingSoon}',
      child: Card(
        color: cardColor,
        elevation: enabled ? 2 : 0,
        shadowColor: colors.orangeDark.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: borderColor, width: enabled ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leadingIcon = Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  icon,
                  color: enabled ? colors.orangeDark : colors.disabledText,
                  size: textScale > 1.35 ? 30 : 36,
                ),
              );
              final textContent = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SingleLineTitle(
                    title: title,
                    style:
                        textTheme.titleLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w700,
                        ) ??
                        TextStyle(
                          color: foregroundColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: secondaryColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!enabled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const _ComingSoonPill(),
                  ],
                ],
              );

              return SizedBox(
                height: cardHeight,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leadingIcon,
                      SizedBox(width: compact ? AppSpacing.md : AppSpacing.lg),
                      Expanded(child: textContent),
                    ],
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

class _SingleLineTitle extends StatelessWidget {
  const _SingleLineTitle({required this.title, required this.style});

  final String title;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(title, maxLines: 1, softWrap: false, style: style),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.disabledSurface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: colors.disabledText,
            ),
            Text(
              AppStrings.comingSoon,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.disabledText),
            ),
          ],
        ),
      ),
    );
  }
}
