import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

abstract final class AppDialog {
  static Future<void> showContent(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
    required String closeLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return _AppDialogFrame(
          title: title,
          icon: icon,
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(closeLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    IconData icon = Icons.info_outline,
    bool isDestructiveConfirm = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;

        return _AppDialogFrame(
          title: title,
          icon: icon,
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isDestructiveConfirm
                  ? TextButton.styleFrom(foregroundColor: colors.error)
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

class _AppDialogFrame extends StatelessWidget {
  const _AppDialogFrame({
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.orangeDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, style: textTheme.titleLarge)),
        ],
      ),
      content: SingleChildScrollView(child: content),
      actions: actions,
    );
  }
}
