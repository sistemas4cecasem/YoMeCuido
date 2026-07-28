import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.orange,
    required this.purple,
    required this.purpleSoft,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.error,
    required this.success,
  });

  static const light = AppPalette(
    orange: Color(0xFFFF8A00),
    purple: Color(0xFF7B1FA2),
    purpleSoft: Color(0xFFF7F2FF),
    background: Color(0xFFFAF8FC),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF17151B),
    textMuted: Color(0xFF6F6878),
    border: Color(0xFFE7E1EB),
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
  );

  static const dark = AppPalette(
    orange: Color(0xFFFF9D24),
    purple: Color(0xFF9C4DCC),
    purpleSoft: Color(0xFF2C1838),
    background: Color(0xFF0B1117),
    surface: Color(0xFF141B23),
    surfaceHigh: Color(0xFF1B2430),
    textPrimary: Color(0xFFF5F7FA),
    textMuted: Color(0xFFAAB3BE),
    border: Color(0xFF2C3744),
    error: Color(0xFFFFB4AB),
    success: Color(0xFF8BD49C),
  );

  final Color orange;
  final Color purple;
  final Color purpleSoft;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color error;
  final Color success;

  @override
  AppPalette copyWith({
    Color? orange,
    Color? purple,
    Color? purpleSoft,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? error,
    Color? success,
  }) {
    return AppPalette(
      orange: orange ?? this.orange,
      purple: purple ?? this.purple,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      orange: Color.lerp(orange, other.orange, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      purpleSoft: Color.lerp(purpleSoft, other.purpleSoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppPaletteAccess on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
