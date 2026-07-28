import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = totalSteps == 0 ? 0.0 : currentStep / totalSteps;

    return Semantics(
      label: '$currentStep de $totalSteps',
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8,
        borderRadius: BorderRadius.circular(999),
        backgroundColor: palette.border,
        color: palette.purple,
      ),
    );
  }
}
