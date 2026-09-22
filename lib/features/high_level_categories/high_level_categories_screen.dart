import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/widgets/app_background.dart';

class HighLevelCategoriesScreen extends StatelessWidget {
  const HighLevelCategoriesScreen({
    required this.connectivityService,
    this.showBackButton = true,
    this.useScaffold = true,
    super.key,
  });

  final ConnectivityService connectivityService;
  final bool showBackButton;
  final bool useScaffold;

  void _openCategoryGroup({
    required BuildContext context,
    required String parentCategoryId,
    required String title,
  }) {
    if (!connectivityService.isOnline) {
      AppToast.showInfo(context, AppStrings.categoryConnectionRequiredSnackBar);
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.categories,
      arguments: CategoriesRouteArguments(
        parentCategoryId: parentCategoryId,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = AnimatedBuilder(
      animation: connectivityService,
      builder: (context, child) {
        final isOnline =
            connectivityService.status == ConnectivityStatus.online;
        return SafeArea(
          child: _HighLevelCategoriesContent(
            showBackButton: showBackButton,
            isOnline: isOnline,
            onTraffickingTap: () => _openCategoryGroup(
              context: context,
              parentCategoryId: ParentCategoryIds.humanTrafficking,
              title: AppStrings.traffickingTitle,
            ),
            onDigitalSecurityTap: () => _openCategoryGroup(
              context: context,
              parentCategoryId: ParentCategoryIds.digitalSecurity,
              title: AppStrings.digitalSecurityTitle,
            ),
            onOfflineActivityTap: () {
              Navigator.of(context).pushNamed(AppRoutes.offlineActivity);
            },
          ),
        );
      },
    );

    if (!useScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),
          content,
        ],
      ),
    );
  }
}

class _HighLevelCategoriesContent extends StatelessWidget {
  const _HighLevelCategoriesContent({
    required this.showBackButton,
    required this.isOnline,
    required this.onTraffickingTap,
    required this.onDigitalSecurityTap,
    required this.onOfflineActivityTap,
  });

  final bool showBackButton;
  final bool isOnline;
  final VoidCallback onTraffickingTap;
  final VoidCallback onDigitalSecurityTap;
  final VoidCallback onOfflineActivityTap;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.md,
                      AppSpacing.screen,
                      AppSpacing.lg,
                    ),
                    child: Center(
                      child: _CenteredCategoryButtons(
                        onTraffickingTap: onTraffickingTap,
                        onDigitalSecurityTap: onDigitalSecurityTap,
                        onOfflineActivityTap: onOfflineActivityTap,
                        isOnline: isOnline,
                      ),
                    ),
                  ),
                ),
              );
            },
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
    required this.onOfflineActivityTap,
    required this.isOnline,
  });

  final VoidCallback onTraffickingTap;
  final VoidCallback onDigitalSecurityTap;
  final VoidCallback onOfflineActivityTap;
  final bool isOnline;

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
              description: AppStrings.traffickingDescription,
              icon: Icons.health_and_safety_outlined,
              enabled: isOnline,
              lockedLabel: AppStrings.connectionRequired,
              onTap: onTraffickingTap,
            ),
            const SizedBox(height: AppSpacing.lg),
            _HighLevelCategoryCard(
              title: AppStrings.digitalSecurityTitle,
              description: AppStrings.digitalSecurityDescription,
              icon: Icons.shield_outlined,
              enabled: isOnline,
              lockedLabel: AppStrings.connectionRequired,
              onTap: onDigitalSecurityTap,
            ),
            const SizedBox(height: AppSpacing.lg),
            _HighLevelCategoryCard(
              title: AppStrings.offlineActivityTitle,
              description: AppStrings.offlineActivityDescription,
              icon: Icons.offline_bolt_outlined,
              enabled: true,
              onTap: onOfflineActivityTap,
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
    this.lockedLabel = AppStrings.comingSoon,
  });

  final String title;
  final String? description;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String lockedLabel;

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
    final cardHeight = !enabled
        ? (compact ? 190.0 : 176.0)
        : (compact ? 164.0 : 152.0);
    final iconSize = compact ? 58.0 : 68.0;
    final padding = compact ? AppSpacing.md : AppSpacing.lg;

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? title : '$title, $lockedLabel',
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
                      maxLines: enabled ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: secondaryColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!enabled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ComingSoonPill(label: lockedLabel),
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
  const _ComingSoonPill({required this.label});

  final String label;

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
              label,
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
