import 'package:flutter/material.dart';

import 'app_theme.dart';

/// ACS Theme Extensions for gradients and status colors
class ACSThemeExtension extends ThemeExtension<ACSThemeExtension> {
  final LinearGradient gradientPrimary;
  final LinearGradient gradientSoftBackground;
  final Color success;
  final Color warning;
  final Color danger;

  const ACSThemeExtension({
    required this.gradientPrimary,
    required this.gradientSoftBackground,
    required this.success,
    required this.warning,
    required this.danger,
  });

  @override
  ThemeExtension<ACSThemeExtension> copyWith({
    LinearGradient? gradientPrimary,
    LinearGradient? gradientSoftBackground,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return ACSThemeExtension(
      gradientPrimary: gradientPrimary ?? this.gradientPrimary,
      gradientSoftBackground: gradientSoftBackground ?? this.gradientSoftBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  ThemeExtension<ACSThemeExtension> lerp(
    ThemeExtension<ACSThemeExtension>? other,
    double t,
  ) {
    if (other is! ACSThemeExtension) {
      return this;
    }

    return ACSThemeExtension(
      gradientPrimary: LinearGradient.lerp(
        gradientPrimary,
        other.gradientPrimary,
        t,
      ) ?? gradientPrimary,
      gradientSoftBackground: LinearGradient.lerp(
        gradientSoftBackground,
        other.gradientSoftBackground,
        t,
      ) ?? gradientSoftBackground,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
    );
  }

  /// Light theme extension
  static const light = ACSThemeExtension(
    gradientPrimary: LinearGradient(
      colors: [
        AppColors.acsBlue,
        AppColors.acsIndigo,
        AppColors.acsPurple,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    gradientSoftBackground: LinearGradient(
      colors: [
        Color(0xFFF0F9FF), // Very light blue
        Color(0xFFEEF2FF), // Very light indigo
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
  );

  /// Dark theme extension
  static const dark = ACSThemeExtension(
    gradientPrimary: LinearGradient(
      colors: [
        AppColors.acsBlue,
        AppColors.acsIndigo,
        AppColors.acsPurple,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    gradientSoftBackground: LinearGradient(
      colors: [
        Color(0xFF0F172A), // Slate 900
        Color(0xFF1E293B), // Slate 800
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
  );
}

/// Extension methods for easy access to ACS theme extensions
extension ACSThemeExtensionX on ThemeData {
  ACSThemeExtension get acs => extension<ACSThemeExtension>()!;
}