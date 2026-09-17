import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AnswerOptionTileState { idle, selected, correct, incorrect }

class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    required this.text,
    required this.onTap,
    this.state = AnswerOptionTileState.idle,
    super.key,
  });

  final String text;
  final AnswerOptionTileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = _borderColor(colors);
    final backgroundColor = _backgroundColor(colors);
    final icon = _icon;
    final isSelected = state != AnswerOptionTileState.idle;

    return Semantics(
      button: true,
      selected: isSelected,
      child: SizedBox(
        width: double.infinity,
        child: Card(
          color: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: borderColor),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _borderColor(AppColors colors) {
    return switch (state) {
      AnswerOptionTileState.correct => const Color(0xFF81C784),
      AnswerOptionTileState.incorrect => colors.error,
      AnswerOptionTileState.selected => colors.orangePrimary,
      AnswerOptionTileState.idle => colors.border,
    };
  }

  Color _backgroundColor(AppColors colors) {
    return switch (state) {
      AnswerOptionTileState.correct => const Color(0xFFE8F5E9),
      AnswerOptionTileState.incorrect => colors.error.withValues(alpha: 0.08),
      AnswerOptionTileState.selected => colors.orangeSoft,
      AnswerOptionTileState.idle => colors.surface,
    };
  }

  IconData? get _icon {
    return switch (state) {
      AnswerOptionTileState.correct => null,
      AnswerOptionTileState.incorrect => Icons.cancel_outlined,
      AnswerOptionTileState.selected => Icons.radio_button_checked_outlined,
      AnswerOptionTileState.idle => null,
    };
  }
}
