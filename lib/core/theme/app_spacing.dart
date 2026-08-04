import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const screen = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const button = 14.0;
  static const card = 16.0;
}

abstract final class AppSizing {
  static const minTouchTarget = 48.0;
  static const primaryButtonHeight = 52.0;
  static const maxContentWidth = 560.0;
  static const characterInlineHeight = 180.0;
  static const characterFeatureHeight = 220.0;
}

abstract final class AppInsets {
  static const screen = EdgeInsets.symmetric(
    horizontal: AppSpacing.screen,
    vertical: AppSpacing.lg,
  );
  static const card = EdgeInsets.all(AppSpacing.md);
  static const button = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
}
