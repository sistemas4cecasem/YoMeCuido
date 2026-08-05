import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AppToastType { info, success, warning, error }

abstract final class AppToast {
  static void showInfo(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.info);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.success);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.warning);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.error);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
  }) {
    final colors = context.colors;
    final visual = _ToastVisual.fromType(type, colors);
    final textTheme = Theme.of(context).textTheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          elevation: 2,
          backgroundColor: colors.surfaceStrong,
          margin: const EdgeInsets.all(AppSpacing.screen),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: visual.borderColor),
          ),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visual.icon, color: visual.iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _ToastVisual {
  const _ToastVisual({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  factory _ToastVisual.fromType(AppToastType type, AppColors colors) {
    return switch (type) {
      AppToastType.info => _ToastVisual(
        icon: Icons.info_outline,
        iconColor: colors.orangeDark,
        borderColor: colors.orangePrimary,
      ),
      AppToastType.success => _ToastVisual(
        icon: Icons.check_circle_outline,
        iconColor: colors.success,
        borderColor: colors.success,
      ),
      AppToastType.warning => _ToastVisual(
        icon: Icons.warning_amber_outlined,
        iconColor: colors.orangeDark,
        borderColor: colors.orangePrimary,
      ),
      AppToastType.error => _ToastVisual(
        icon: Icons.error_outline,
        iconColor: colors.error,
        borderColor: colors.error,
      ),
    };
  }
}
