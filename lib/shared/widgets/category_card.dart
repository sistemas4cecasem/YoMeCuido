import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.category,
    required this.onTap,
    this.isUnlocked,
    this.lockedLabel,
    super.key,
  });

  final Category category;
  final VoidCallback onTap;
  final bool? isUnlocked;
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final enabled = isUnlocked ?? category.isEnabled;
    final effectiveLockedLabel = lockedLabel ?? AppStrings.comingSoon;
    final iconColor = enabled ? colors.orangeDark : colors.disabledText;
    final iconBackground = enabled ? colors.orangeSoft : colors.disabledSurface;
    final borderColor = enabled ? colors.orangePrimary : colors.border;

    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? category.title
          : '${category.title}, $effectiveLockedLabel',
      child: Card(
        color: enabled ? colors.surface : colors.disabledSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: borderColor, width: enabled ? 1.5 : 1),
        ),
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
                    border: Border.all(color: borderColor),
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
                              ? colors.textPrimary
                              : colors.disabledText,
                        ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _LockedPill(
                          colors: colors,
                          label: effectiveLockedLabel,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Tooltip(
                    message: effectiveLockedLabel,
                    child: Semantics(
                      label: effectiveLockedLabel,
                      child: Icon(
                        Icons.lock_outline,
                        color: colors.disabledText,
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

class _LockedPill extends StatelessWidget {
  const _LockedPill({required this.colors, required this.label});

  final AppColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.disabledSurface,
        border: Border.all(color: colors.border),
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
            Icon(Icons.lock_outline, size: 14, color: colors.disabledText),
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
