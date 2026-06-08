import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// IST (India Standard Time, UTC+5:30) utilities for server timestamps.
/// Backend sends ISO strings (Z or +05:30); app stores UTC and displays IST consistently.
abstract final class IstTime {
  IstTime._();

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Parses server ISO timestamp (handles Z or +05:30). Returns [DateTime] in UTC, or null.
  static DateTime? parseServerTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final s = iso.trim();
    
    // Check if it's a date-only string (YYYY-MM-DD)
    final dateOnlyRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (dateOnlyRegex.hasMatch(s)) {
      return DateTime.tryParse(s);
    }

    final hasOffset = s.endsWith('Z') ||
        s.contains('+') ||
        (s.contains('-') && s.indexOf('-', 1) > 10);
    final toParse = hasOffset ? s : '$s${s.endsWith('Z') ? '' : 'Z'}';
    final parsed = DateTime.tryParse(toParse);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed : DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    );
  }

  /// Converts UTC [DateTime] to IST wall-clock (for display). Does not change the instant.
  static DateTime toIst(DateTime utc) {
    final utcMs = utc.isUtc
        ? utc.millisecondsSinceEpoch
        : DateTime.utc(
            utc.year,
            utc.month,
            utc.day,
            utc.hour,
            utc.minute,
            utc.second,
            utc.millisecond,
          ).millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(
      utcMs + _istOffset.inMilliseconds,
      isUtc: true,
    );
  }

  /// Formats server ISO string as HH:mm in IST. Returns '--:--' if null or unparseable.
  static String formatHHmmIst(String? iso) {
    final utc = parseServerTime(iso);
    return formatHHmmFromUtc(utc);
  }

  /// Formats UTC [DateTime] as HH:mm in IST. Returns '--:--' if null.
  static String formatHHmmFromUtc(DateTime? utc) {
    if (utc == null) return '--:--';
    final ist = toIst(utc);
    return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}';
  }

  /// Formats UTC [DateTime] as time with AM/PM in IST. Returns '--:--' if null.
  static String formatTimeFromUtc(DateTime? utc) {
    if (utc == null) return '--:--';
    final ist = toIst(utc);
    return DateFormat('hh:mm a').format(ist);
  }

  /// Formats server ISO string as date in IST (e.g. "7 Feb 2025"). Returns '--' if null or unparseable.
  static String formatDateIst(String? iso) {
    final utc = parseServerTime(iso);
    return formatDateFromUtc(utc);
  }

  /// Formats UTC [DateTime] as date in IST. Returns '--' if null.
  static String formatDateFromUtc(DateTime? utc) {
    if (utc == null) return '--';
    // If the date is already local (like a work_date YYYY-MM-DD), just format it.
    if (!utc.isUtc) {
      return DateFormat('d MMM yyyy').format(utc);
    }
    final ist = toIst(utc);
    return DateFormat('d MMM yyyy').format(DateTime(ist.year, ist.month, ist.day));
  }

  /// Formats UTC [DateTime] as date and time in IST. Returns '--' if null.
  static String formatDateTimeFromUtc(DateTime? utc) {
    if (utc == null) return '--';
    final ist = toIst(utc);
    return DateFormat('d MMM yyyy, hh:mm a').format(ist);
  }

  /// One-time debug log: raw server string, parsed UTC, IST, final displayed value.
  static void debugLog(String label, String? raw, DateTime? parsedUtc) {
    if (!kDebugMode || raw == null) return;
    final ist = parsedUtc != null ? toIst(parsedUtc) : null;
    final displayed = parsedUtc != null ? formatHHmmFromUtc(parsedUtc) : '--:--';
    // ignore: avoid_print
    print('🕐 [IstTime] $label raw="$raw" parsedUtc=$parsedUtc ist=$ist displayed=$displayed');
  }
}
