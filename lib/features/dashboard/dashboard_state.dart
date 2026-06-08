import '../../core/utils/ist_time.dart';

/// Dashboard data state. Punch times are DateTime in UTC; working hours computed from them (no double-convert).
class DashboardState {
  const DashboardState({
    this.employeeName = '',
    this.punchInTime,
    this.punchOutTime,
    this.pendingLeaves = 0,
    this.pendingApprovals = 0,
    this.totalHolidays = 0,
    this.totalRestrictedHolidays = 0,
    this.isLoading = false,
    this.error,
  });

  final String employeeName;
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final int pendingLeaves;
  final int pendingApprovals;
  final int totalHolidays;
  final int totalRestrictedHolidays;
  final bool isLoading;
  final Object? error;

  /// Format time as HH:mm in IST; null → '--:--'. [d] is UTC.
  static String formatTime(DateTime? d) => IstTime.formatHHmmFromUtc(d);

  /// Format duration as "Xh XXm".
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Working duration from punch in to punch out (or now UTC if punch out is null). Uses UTC only; no double-convert.
  static Duration? calculateWorkingHours(
      DateTime? punchIn, DateTime? punchOut) {
    if (punchIn == null) return null;
    final end = punchOut ?? DateTime.now().toUtc();
    var d = end.difference(punchIn);
    if (d.isNegative) d = Duration.zero;
    return d;
  }

  String get punchInFormatted => formatTime(punchInTime);
  String get punchOutFormatted => formatTime(punchOutTime);

  /// Computed from DateTime difference; when punch_out is null uses current time. Never use decimal.
  String get workingHoursText {
    final d = calculateWorkingHours(punchInTime, punchOutTime);
    if (d == null) return '0h 00m';
    return formatDuration(d);
  }

  /// True when user has punched in but not out (session open).
  bool get isAttendanceOpen => punchInTime != null && punchOutTime == null;

  /// True when user has completed attendance (both punch in and punch out).
  bool get isAttendanceComplete => punchInTime != null && punchOutTime != null;

  DashboardState copyWith({
    String? employeeName,
    DateTime? punchInTime,
    DateTime? punchOutTime,
    int? pendingLeaves,
    int? pendingApprovals,
    int? totalHolidays,
    int? totalRestrictedHolidays,
    bool? isLoading,
    Object? error,
  }) {
    return DashboardState(
      employeeName: employeeName ?? this.employeeName,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      pendingLeaves: pendingLeaves ?? this.pendingLeaves,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      totalHolidays: totalHolidays ?? this.totalHolidays,
      totalRestrictedHolidays:
          totalRestrictedHolidays ?? this.totalRestrictedHolidays,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  String toString() {
    return 'DashboardState(employeeName: $employeeName, isLoading: $isLoading, error: $error)';
  }
}
