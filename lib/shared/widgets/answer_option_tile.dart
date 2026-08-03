import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    required this.text,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = isSelected ? colors.orangePrimary : colors.border;
    final backgroundColor = isSelected ? colors.orangeSoft : colors.surface;

    return Semantics(
      button: true,
      selected: isSelected,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usesLargeText =
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final icon = Icon(
                isSelected
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: isSelected ? colors.orangeDark : colors.textSecondary,
              );
              final label = Text(
                text,
                style: textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: usesLargeText || constraints.maxWidth < 300
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(height: AppSpacing.xs),
                          label,
                        ],
                      )
                    : Row(
                        children: [
                          icon,
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: label),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
