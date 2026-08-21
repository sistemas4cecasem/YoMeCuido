import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';

enum DemoNavItem { home, progress }

class DemoBottomNavigationBar extends StatelessWidget {
  const DemoBottomNavigationBar({this.selectedItem, this.category, super.key});

  final DemoNavItem? selectedItem;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                label: AppStrings.homeTitle,
                selected: selectedItem == DemoNavItem.home,
                onTap: () => Navigator.of(context).popUntil((route) {
                  return route.settings.name == AppRoutes.categories ||
                      route.isFirst;
                }),
              ),
              _NavButton(
                icon: Icons.tune_outlined,
                label: AppStrings.summaryTitle,
                selected: selectedItem == DemoNavItem.progress,
                onTap: category == null || selectedItem == DemoNavItem.progress
                    ? null
                    : () => Navigator.of(context).pushNamed(
                        AppRoutes.categorySummary,
                        arguments: category,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = colors.orangeDark;
    final inactiveColor = colors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
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
                  icon,
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
