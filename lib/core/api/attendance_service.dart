import 'package:acs_hrms/core/api/attendance_api.dart';
import 'package:acs_hrms/core/api/attendance_dto.dart';
import 'package:acs_hrms/core/api/api_repository.dart';

/// Service layer for attendance. Delegates to AttendanceApi (Bearer token attached there via Dio).
class AttendanceService {
  AttendanceService({required AttendanceApi attendanceApi}) : _api = attendanceApi;

  final AttendanceApi _api;

  Future<AttendanceSessionDto> punchIn({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) =>
      _api.punchIn(
        deviceId: deviceId,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        capturedAt: capturedAt,
        address: address,
      );

  Future<AttendanceSessionDto> punchOut({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) =>
      _api.punchOut(
        deviceId: deviceId,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        capturedAt: capturedAt,
        address: address,
      );

  /// Today's session from GET /attendance/today.
  Future<AttendanceSessionDto?> getTodaySession() => _api.getToday();

  /// My sessions from GET /attendance/my?from=YYYY-MM-DD&to=YYYY-MM-DD. Uses local date only (no UTC).
  Future<List<AttendanceSessionDto>> getMySessions(DateTime from, DateTime to) {
    final fromLocal = DateTime(from.year, from.month, from.day);
    final toLocal = DateTime(to.year, to.month, to.day);
    return _api.getMy(from: fromLocal, to: toLocal);
  }

  /// List from GET /attendance/list (optional from/to if backend supports).
  Future<List<AttendanceSessionDto>> list({DateTime? from, DateTime? to}) =>
      _api.list(from: from, to: to);

  /// Legacy: today's attendance for dashboard (punch times + working hours text).
  Future<TodayAttendanceDto> today() async {
    final session = await _api.getToday();
    if (session == null) {
      return TodayAttendanceDto(punchInTime: null, punchOutTime: null, workingHoursText: '0h 00m');
    }
    return TodayAttendanceDto(
      punchInTime: session.punchInAt,
      punchOutTime: session.punchOutAt,
      workingHoursText: session.workingHoursText,
    );
  }

  Future<AttendanceStreakDto> streak({int window = 30}) {
    return _api.getStreak(window: window);
  }

  /// Calculates punctuality streak and consistency locally.
  /// Streak cutoff: before 10:00 AM.
  /// Skips holidays, week-offs, and approved leaves.
  Future<AttendanceStreakDto> calculatePunctualityStreak({
    int window = 30,
    required List<HolidayDto> holidays,
    required List<LeaveDto> leaves,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Fetch attendance for the window + extra buffer for streak
    final fromDate = today.subtract(Duration(days: window + 30));
    final sessions = await getMySessions(fromDate, today);
    
    // Map sessions by date for quick lookup
    final sessionMap = <String, AttendanceSessionDto>{};
    for (final s in sessions) {
      if (s.workDate != null) {
        sessionMap[AttendanceApi.fmtDate(s.workDate!)] = s;
      } else if (s.punchInAt != null) {
        sessionMap[AttendanceApi.fmtDate(s.punchInAt!)] = s;
      }
    }

    bool isExcluded(DateTime date) {
      // Week-off (Sunday)
      if (date.weekday == DateTime.sunday) return true;
      
      final dateStr = AttendanceApi.fmtDate(date);
      
      // Holiday
      if (holidays.any((h) => AttendanceApi.fmtDate(h.date) == dateStr)) return true;
      
      // Approved Leave
      if (leaves.any((l) => 
          l.status == 'approved' && 
          !date.isBefore(DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day)) && 
          !date.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)))) {
        return true;
      }
      
      return false;
    }

    bool isPunctual(AttendanceSessionDto? s) {
      if (s == null || s.punchInAt == null) return false;
      // Before 10:00 AM strictly
      return s.punchInAt!.hour < 10;
    }

    // 1. Calculate Current Streak
    int currentStreak = 0;
    DateTime checkDate = today;
    
    // Special handling for today
    final todaySession = sessionMap[AttendanceApi.fmtDate(today)];
    if (!isExcluded(today)) {
      if (todaySession != null) {
        if (isPunctual(todaySession)) {
          currentStreak = 1;
        } else {
          // Late today breaks the streak
          currentStreak = 0;
          checkDate = today.subtract(const Duration(days: 1)); // Skip loop
        }
      } else {
        // Not punched in today yet
        if (now.hour >= 10) {
          // Already late (missing punch after 10 AM)
          currentStreak = 0;
          checkDate = today.subtract(const Duration(days: 1)); // Skip loop
        } else {
          // Still have time today, streak is based on yesterday
        }
      }
    }

    // Loop backwards from yesterday
    if (checkDate == today) {
      checkDate = today.subtract(const Duration(days: 1));
      while (true) {
        if (isExcluded(checkDate)) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        
        final s = sessionMap[AttendanceApi.fmtDate(checkDate)];
        if (isPunctual(s)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          // Late or absent breaks streak
          break;
        }
        
        // Safety break
        if (currentStreak > 365) break;
      }
    }

    // 2. Calculate Consistency in Window
    int totalEligibleDays = 0;
    int qualifyingDays = 0;
    
    for (int i = 0; i < window; i++) {
      final date = today.subtract(Duration(days: i));
      if (isExcluded(date)) continue;
      
      totalEligibleDays++;
      final s = sessionMap[AttendanceApi.fmtDate(date)];
      
      if (date.isAtSameMomentAs(today)) {
        // For today, only count if already punched in punctually
        if (isPunctual(s)) {
          qualifyingDays++;
        }
      } else {
        if (isPunctual(s)) {
          qualifyingDays++;
        }
      }
    }

    final consistency = totalEligibleDays > 0 
        ? (qualifyingDays * 100 ~/ totalEligibleDays) 
        : 0;

    return AttendanceStreakDto(
      currentStreakDays: currentStreak,
      consistencyPercent: consistency,
      windowDays: window,
      goodDays: qualifyingDays,
      workDays: totalEligibleDays,
    );
  }
}
