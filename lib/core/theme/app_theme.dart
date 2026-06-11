import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'acs_theme_ext.dart';

/// App-wide spacing (enterprise layout).
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  static const EdgeInsets paddingScreen = EdgeInsets.all(md);
  static const EdgeInsets paddingCard = EdgeInsets.all(md);
  static const EdgeInsets paddingList = EdgeInsets.symmetric(horizontal: md, vertical: sm);
  static const double paddingBottomSafe = 24;
}

/// Unified dimensions: card radius, button height, icon sizes (production ERP consistency).
abstract final class AppDimensions {
  AppDimensions._();

  static const double cardRadius = 14;
  static const double cardRadiusSmall = 8;
  static const double buttonRadius = 12;
  static const double buttonMinHeight = 52;

  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;
}

/// Consistent border radii for enterprise UI
abstract final class AppRadii {
  AppRadii._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

/// Consistent elevation values for depth hierarchy
abstract final class AppElevation {
  AppElevation._();

  static const double card = 1.5;
  static const double modal = 6;
}

/// ACS Brand Colors - Inspired by ACS logo palette
abstract final class AppColors {
  AppColors._();

  // ACS Primary Brand Colors
  static const Color acsBlue = Color(0xFF3285CE);
  static const Color acsCyan = Color(0xFF129FE3);
  static const Color acsIndigo = Color(0xFF506DBB);
  static const Color acsPurple = Color(0xFF6E54A7);
  static const Color acsSlate = Color(0xFF475569);

  // Enterprise status and semantic colors
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0369A1);

  // Surface and background colors
  static const Color backgroundLight = Color(0xFFF7F8FC); // Near-white enterprise surface
  static const Color cardLight = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF0F172A); // Dark neutral
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
}

/// Material 3 theme — enterprise palette, calm, no gradients.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.acsIndigo,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE0E7FF),
          onPrimaryContainer: AppColors.acsIndigo,
          secondary: AppColors.acsBlue,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFE0F2FE),
          onSecondaryContainer: Color(0xFF0369A1),
          tertiary: AppColors.acsCyan,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFCFFAFE),
          onTertiaryContainer: Color(0xFF164E63),
          error: AppColors.error,
          onError: Colors.white,
          errorContainer: Color(0xFFFEE2E2),
          onErrorContainer: AppColors.error,
          background: Color(0xFFF8FAFC),
          onBackground: Color(0xFF0F172A),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
          surfaceVariant: Color(0xFFF1F5F9),
          onSurfaceVariant: Color(0xFF475569),
          outline: Color(0xFFCBD5E1),
          outlineVariant: Color(0xFFE2E8F0),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFF1E293B),
          onInverseSurface: Color(0xFFF8FAFC),
          inversePrimary: Color(0xFFC7D2FE),
          surfaceTint: AppColors.acsIndigo,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        textTheme: _textTheme(GoogleFonts.interTextTheme(Typography.material2021().black)).apply(
          bodyColor: const Color(0xFF0F172A), // onSurface
          displayColor: const Color(0xFF0F172A), // onSurface
        ),
        typography: Typography.material2021(),
        // Explicit icon theme: do NOT set fontFamily so Material Icons (Icons.*) render correctly.
        iconTheme: const IconThemeData(color: Color(0xFF475569), size: 24),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          titleTextStyle: Typography.material2021().black.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
          backgroundColor: AppColors.cardLight,
          elevation: 0.5,
          scrolledUnderElevation: 1,
          iconTheme: const IconThemeData(color: AppColors.textSecondary),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          surfaceTintColor: AppColors.acsIndigo,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: const BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.acsIndigo, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.buttonMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.buttonMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.buttonMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            side: BorderSide(color: AppColors.acsIndigo, width: 1.5),
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.acsIndigo,
            ),
          ),
        ),
        extensions: const <ThemeExtension<dynamic>>[
          ACSThemeExtension.light,
        ],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.acsIndigo,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF1E3A8A),
          onPrimaryContainer: Color(0xFFDBEAFE),
          secondary: AppColors.acsBlue,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFF0C4A6E),
          onSecondaryContainer: Color(0xFFE0F2FE),
          tertiary: AppColors.acsCyan,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFF164E63),
          onTertiaryContainer: Color(0xFFCFFAFE),
          error: AppColors.error,
          onError: Colors.white,
          errorContainer: Color(0xFF7F1D1D),
          onErrorContainer: Color(0xFFFEE2E2),
          background: Color(0xFF0F172A),
          onBackground: Color(0xFFF8FAFC),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF8FAFC),
          surfaceVariant: Color(0xFF334155),
          onSurfaceVariant: Color(0xFFCBD5E1),
          outline: Color(0xFF64748B),
          outlineVariant: Color(0xFF475569),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFFF8FAFC),
          onInverseSurface: Color(0xFF0F172A),
          inversePrimary: Color(0xFF1E3A8A),
          surfaceTint: AppColors.acsIndigo,
        ),
        textTheme: _textTheme(GoogleFonts.interTextTheme(Typography.material2021().white)).apply(
          bodyColor: const Color(0xFFF8FAFC), // onSurface for dark
          displayColor: const Color(0xFFF8FAFC), // onSurface for dark
        ),
        typography: Typography.material2021(),
        // Explicit icon theme: do NOT set fontFamily so Material Icons render correctly.
        iconTheme: const IconThemeData(size: 24),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0.5,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          surfaceTintColor: AppColors.acsIndigo,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            side: const BorderSide(
              color: Color(0xFF475569),
              width: 1,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: Color(0xFF475569), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: Color(0xFF475569), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.acsIndigo, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          filled: true,
          fillColor: const Color(0xFF334155),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.buttonMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.buttonMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
            ),
          ),
        ),
        extensions: const <ThemeExtension<dynamic>>[
          ACSThemeExtension.dark,
        ],
      );

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: base.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
