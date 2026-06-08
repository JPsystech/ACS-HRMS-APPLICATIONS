import '../../core/utils/ist_time.dart';

/// In-memory dummy state for today's attendance (UI-only). Times in UTC; display via IstTime.
class TodayAttendanceState {
  TodayAttendanceState._();

  static DateTime? punchInTime;
  static DateTime? punchOutTime;

  static String get punchInFormatted => IstTime.formatHHmmFromUtc(punchInTime);
  static String get punchOutFormatted => IstTime.formatHHmmFromUtc(punchOutTime);

  static String get workingHoursFormatted {
    if (punchInTime == null) return '0h 00m';
    final end = punchOutTime ?? DateTime.now().toUtc();
    final diff = end.difference(punchInTime!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static void setPunchIn(DateTime time) {
    punchInTime = time;
  }

  static void setPunchOut(DateTime time) {
    punchOutTime = time;
  }
}
