import 'package:flutter/material.dart';

/// App typography hierarchy: titles, subtitles, body.
abstract final class AppTypography {
  AppTypography._();

  /// Page/section title (e.g. "Hi, Employee").
  static TextStyle titleLarge(TextTheme base, Color color) =>
      (base.titleLarge ?? base.bodyLarge!).copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Card/section heading (e.g. "Today's Attendance").
  static TextStyle titleMedium(TextTheme base, Color color) =>
      (base.titleMedium ?? base.bodyMedium!).copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// List item title, chip label.
  static TextStyle titleSmall(TextTheme base, Color color) =>
      (base.titleSmall ?? base.bodySmall!).copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Body text (default).
  static TextStyle bodyLarge(TextTheme base, Color color) =>
      (base.bodyLarge ?? const TextStyle()).copyWith(color: color);

  /// Secondary body (e.g. date, time).
  static TextStyle bodyMedium(TextTheme base, Color color) =>
      (base.bodyMedium ?? base.bodyLarge!).copyWith(color: color);

  /// Caption, hint, metadata (e.g. "Pending Leaves: 0").
  static TextStyle bodySmall(TextTheme base, Color color) =>
      (base.bodySmall ?? base.bodyMedium!).copyWith(color: color);

  /// Label (e.g. form labels, section "Info").
  static TextStyle labelSmall(TextTheme base, Color color) =>
      (base.labelSmall ?? base.bodySmall!).copyWith(
        fontWeight: FontWeight.w500,
        color: color,
      );
}
