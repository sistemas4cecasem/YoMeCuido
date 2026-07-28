import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({required this.category, required this.onTap, super.key});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final enabled = category.isEnabled;
    final iconColor = enabled ? palette.purple : palette.textMuted;
    final iconBackground = enabled ? palette.purpleSoft : palette.surfaceHigh;

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? category.title
          : '${category.title}, ${AppStrings.comingSoon}',
      child: Card(
        color: enabled ? palette.surface : palette.surfaceHigh,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSizing.minTouchTarget,
                  height: AppSizing.minTouchTarget,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(
                    categoryIconFromName(category.iconName),
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: enabled
                              ? palette.textPrimary
                              : palette.textMuted,
                        ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _ComingSoonPill(palette: palette),
                      ],
                    ],
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Tooltip(
                    message: AppStrings.comingSoon,
                    child: Semantics(
                      label: AppStrings.comingSoon,
                      child: Icon(
                        Icons.lock_outline,
                        color: palette.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            Icon(Icons.lock_outline, size: 14, color: palette.textMuted),
            Text(
              AppStrings.comingSoon,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

IconData categoryIconFromName(String iconName) {
  return switch (iconName) {
    'shield_outlined' => Icons.shield_outlined,
    'groups_outlined' => Icons.groups_outlined,
    'lock_outline' => Icons.lock_outline,
    'phone_android_outlined' => Icons.phone_android_outlined,
    'badge_outlined' => Icons.badge_outlined,
    'verified_user_outlined' => Icons.verified_user_outlined,
    'mark_email_unread_outlined' => Icons.mark_email_unread_outlined,
    'credit_card_outlined' => Icons.credit_card_outlined,
    'fact_check_outlined' => Icons.fact_check_outlined,
    'health_and_safety_outlined' => Icons.health_and_safety_outlined,
    'restore_outlined' => Icons.restore_outlined,
    _ => Icons.category_outlined,
  };
}
