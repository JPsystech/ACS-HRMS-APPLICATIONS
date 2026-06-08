import 'package:flutter/foundation.dart';

import 'ist_time.dart';

/// Parses server timestamps to [DateTime] in UTC. Display using [IstTime.formatHHmmFromUtc] etc. for IST.
///
/// - String: ISO with Z or +05:30 via [IstTime.parseServerTime]; returns UTC.
/// - Date-only String (YYYY-MM-DD): returns as a local date (time at 00:00).
/// - Int (ms since epoch): treated as UTC.
/// - Num: same as int, or time-of-day decimal (0–24) as today local (legacy).
/// - Returns null for null or unparseable values.
DateTime? parseServerDateTime(dynamic value, {String? debugLabel, bool isDateOnly = false}) {
  if (value == null) return null;

  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;

    if (isDateOnly) {
      final dateOnlyRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (dateOnlyRegex.hasMatch(s)) {
        final parsed = DateTime.tryParse(s);
        if (kDebugMode && debugLabel != null) {
          debugPrint('📅 [ServerDateTime] $debugLabel raw_date=$s parsedLocal=$parsed');
        }
        return parsed;
      }
    }

    final parsed = IstTime.parseServerTime(s);
    if (kDebugMode && debugLabel != null) {
      IstTime.debugLog(debugLabel, s, parsed);
    }
    return parsed;
  }

  if (value is int) {
    // Check if value is in seconds or milliseconds
    final int ms = value < 10000000000 ? value * 1000 : value;
    final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    if (kDebugMode && debugLabel != null) {
      debugPrint('🕐 [ServerDateTime] $debugLabel raw_int=$value parsedUtc=$utc');
    }
    return utc;
  }

  if (value is num) {
    final n = value.toDouble();
    if (n >= 0 && n < 24 && n != n.round()) {
      final now = DateTime.now();
      final h = n.floor().clamp(0, 23);
      final m = ((n - h) * 60).round().clamp(0, 59);
      return DateTime(now.year, now.month, now.day, h, m);
    }
    
    // Check if value is in seconds or milliseconds
    final int ms = n < 10000000000 ? n.toInt() * 1000 : n.toInt();
    final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    if (kDebugMode && debugLabel != null) {
      debugPrint('🕐 [ServerDateTime] $debugLabel raw_num=$value parsedUtc=$utc');
    }
    return utc;
  }

  return null;
}
