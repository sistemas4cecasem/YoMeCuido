import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.orangePrimary,
    required this.orangeDark,
    required this.orangeSoft,
    required this.purpleSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.disabledSurface,
    required this.disabledText,
    required this.success,
    required this.error,
  });

  static const fixed = AppColors(
    background: Color(0xFFFFF3E0),
    surface: Color(0xFFFFFBF6),
    surfaceStrong: Color(0xFFFFFFFF),
    orangePrimary: Color(0xFFFF8A00),
    orangeDark: Color(0xFFC95D00),
    orangeSoft: Color(0xFFFFE2BD),
    purpleSecondary: Color(0xFF7B1FA2),
    textPrimary: Color(0xFF241A14),
    textSecondary: Color(0xFF6E5D52),
    border: Color(0xFFE8D8CA),
    disabledSurface: Color(0xFFF2EAE3),
    disabledText: Color(0xFF91857C),
    success: Color(0xFF2E7D32),
    error: Color(0xFFB3261E),
  );

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color orangePrimary;
  final Color orangeDark;
  final Color orangeSoft;
  final Color purpleSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color disabledSurface;
  final Color disabledText;
  final Color success;
  final Color error;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceStrong,
    Color? orangePrimary,
    Color? orangeDark,
    Color? orangeSoft,
    Color? purpleSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? disabledSurface,
    Color? disabledText,
    Color? success,
    Color? error,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      orangePrimary: orangePrimary ?? this.orangePrimary,
      orangeDark: orangeDark ?? this.orangeDark,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      purpleSecondary: purpleSecondary ?? this.purpleSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      disabledText: disabledText ?? this.disabledText,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      orangePrimary: Color.lerp(orangePrimary, other.orangePrimary, t)!,
      orangeDark: Color.lerp(orangeDark, other.orangeDark, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      purpleSecondary: Color.lerp(purpleSecondary, other.purpleSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppColorsAccess on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
