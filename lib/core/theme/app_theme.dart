import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.purple,
      onPrimary: Colors.white,
      secondary: palette.orange,
      onSecondary: Colors.black,
      error: palette.error,
      onError: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF601410),
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );

    final textTheme = AppTypography.textTheme(
      palette.textPrimary,
      palette.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: brightness == Brightness.light ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: palette.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizing.primaryButtonHeight),
          padding: AppInsets.button,
          elevation: 0,
          backgroundColor: palette.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textMuted,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizing.primaryButtonHeight),
          padding: AppInsets.button,
          foregroundColor: brightness == Brightness.light
              ? palette.purple
              : palette.textPrimary,
          disabledForegroundColor: palette.textMuted,
          textStyle: textTheme.labelLarge,
          side: BorderSide(
            color: brightness == Brightness.light
                ? palette.border
                : palette.purple,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: palette.purple),
      dividerTheme: DividerThemeData(color: palette.border),
    );
  }
}
