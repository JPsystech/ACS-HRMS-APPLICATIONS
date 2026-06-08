import 'package:flutter/foundation.dart';

import '../utils/server_datetime_util.dart';

/// Geo payload for a single punch (in or out): location + address.
class PunchGeoDto {
  const PunchGeoDto({
    this.lat,
    this.lng,
    this.accuracy,
    this.capturedAt,
    this.source,
    this.isMocked,
    this.address,
  });

  final double? lat;
  final double? lng;

  /// Accuracy in meters.
  final double? accuracy;
  final DateTime? capturedAt;
  final String? source;
  final bool? isMocked;

  /// Reverse-geocoded human-readable address (city, area, state).
  final String? address;

  bool get hasLocation =>
      (lat != null && lng != null) ||
      (address != null && address!.trim().isNotEmpty) ||
      accuracy != null;

  static PunchGeoDto? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final lat = _parseDouble(json['lat']);
    final lng = _parseDouble(json['lng']);
    final accuracy = _parseDouble(json['accuracy']);
    final capturedAt = parseServerDateTime(
      json['captured_at'] ?? json['capturedAt'],
      debugLabel: 'geo.captured_at',
    );
    final source = json['source'] as String?;
    final isMocked = json['is_mocked'] as bool? ?? json['isMocked'] as bool?;
    final address = (json['address'] as String?)?.trim();
    if (lat == null && lng == null && accuracy == null && address == null)
      return null;
    return PunchGeoDto(
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      capturedAt: capturedAt,
      source: source,
      isMocked: isMocked,
      address: address?.isEmpty == true ? null : address,
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class AttendanceStreakDto {
  const AttendanceStreakDto({
    required this.currentStreakDays,
    required this.consistencyPercent,
    required this.windowDays,
    required this.goodDays,
    required this.workDays,
  });

  final int currentStreakDays;
  final int consistencyPercent;
  final int windowDays;
  final int goodDays;
  final int workDays;

  factory AttendanceStreakDto.fromJson(Map<String, dynamic> m) {
    return AttendanceStreakDto(
      currentStreakDays: (m['current_streak_days'] ?? 0) as int,
      consistencyPercent: (m['consistency_percent'] ?? 0) as int,
      windowDays: (m['window_days'] ?? m['work_days'] ?? 0) as int,
      goodDays: (m['good_days'] ?? 0) as int,
      workDays: (m['work_days'] ?? m['window_days'] ?? 0) as int,
    );
  }
}

/// DTO for a single attendance session (punch in/out).
class AttendanceSessionDto {
  const AttendanceSessionDto({
    required this.id,
    required this.employeeId,
    this.workDate,
    this.punchInAt,
    this.punchOutAt,
    this.status = 'open',
    this.remarks,
    this.punchInGeo,
    this.punchOutGeo,
  });

  final String id;
  final String employeeId;
  final DateTime? workDate;
  final DateTime? punchInAt;
  final DateTime? punchOutAt;
  final String status;
  final String? remarks;
  final PunchGeoDto? punchInGeo;
  final PunchGeoDto? punchOutGeo;

  /// Whether this session has been punched in (has punch_in_at).
  bool get isPunchedIn => punchInAt != null;

  /// Whether this session is completed (has punch_out_at).
  bool get isCompleted => punchOutAt != null;

  /// Working duration from punch_in_at to punch_out_at (or now UTC if still open). Uses UTC only.
  Duration? get workingDuration {
    if (punchInAt == null) return null;
    final end = punchOutAt ?? DateTime.now().toUtc();
    var d = end.difference(punchInAt!);
    if (d.isNegative) d = Duration.zero;
    if (kDebugMode) {
      _logWorkingMinutesOnce(this, d);
    }
    return d;
  }

  static int? _lastLoggedPunchInMs;
  static int? _lastLoggedPunchOutMs;
  static int? _lastLoggedMinute;

  /// Log at most once per minute for open sessions, or once when punch state changes (e.g. punch out). Stops log spam from Timer-driven rebuilds.
  static void _logWorkingMinutesOnce(AttendanceSessionDto session, Duration d) {
    final punchInMs = session.punchInAt!.millisecondsSinceEpoch;
    final punchOutMs = session.punchOutAt?.millisecondsSinceEpoch;
    final minutes = d.inMinutes;
    final sessionChanged = punchInMs != _lastLoggedPunchInMs ||
        punchOutMs != _lastLoggedPunchOutMs;
    final isOpen = session.punchOutAt == null;
    final minuteChanged = minutes != _lastLoggedMinute;
    if (!sessionChanged && (!isOpen || !minuteChanged)) return;
    _lastLoggedPunchInMs = punchInMs;
    _lastLoggedPunchOutMs = punchOutMs;
    _lastLoggedMinute = minutes;
    if (kDebugMode) {
      debugPrint('🕐 [Attendance] worked minutes=$minutes');
    }
  }

  /// Formatted working hours string (e.g. "5h 34m" or "0h 00m"). Uses session timestamps only; running duration uses now when punch_out is null.
  String get workingHoursText {
    final d = workingDuration;
    if (d == null) return '0h 00m';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Parse from API JSON (snake_case or camelCase). Reads remarks + punch_in_geo / punch_out_geo.
  /// All timestamps parsed via [parseServerDateTime] to local time.
  static AttendanceSessionDto fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id']?.toString() ?? '';
      final employeeId = json['employee_id']?.toString() ??
          json['employeeId']?.toString() ??
          '';
      final workDate = parseServerDateTime(
        json['work_date'] ?? json['workDate'],
        debugLabel: 'work_date',
        isDateOnly: true,
      );
      final punchInAt = parseServerDateTime(
          json['punch_in_at'] ??
              json['punchInAt'] ??
              json['punch_in_time'] ??
              json['punchInTime'],
          debugLabel: 'punch_in_at');
      final punchOutAt = parseServerDateTime(
          json['punch_out_at'] ??
              json['punchOutAt'] ??
              json['punch_out_time'] ??
              json['punchOutTime'],
          debugLabel: 'punch_out_at');
      final statusStr =
          json['status'] as String? ?? (punchOutAt != null ? 'closed' : 'open');
      final remarks = _readRemark(json, [
        'remarks',
        'remark',
        'punch_remark',
        'punchRemark',
        'note',
        'comment',
        'punch_in_remark',
        'punchInRemark',
        'punch_out_remark',
        'punchOutRemark',
        'action_remark',
        'actionRemark',
      ]);
      final punchInGeo = PunchGeoDto.fromJson(
          _geoMap(json['punch_in_geo'] ?? json['punchInGeo']));
      final punchOutGeo = PunchGeoDto.fromJson(
          _geoMap(json['punch_out_geo'] ?? json['punchOutGeo']));

      if (kDebugMode && remarks != null && remarks.trim().isNotEmpty) {
        debugPrint('📋 [Attendance] parsed remarks: $remarks');
      }

      return AttendanceSessionDto(
        id: id,
        employeeId: employeeId,
        workDate: workDate,
        punchInAt: punchInAt,
        punchOutAt: punchOutAt,
        status: statusStr,
        remarks: remarks,
        punchInGeo: punchInGeo,
        punchOutGeo: punchOutGeo,
      );
    } catch (e, st) {
      print('❌ [AttendanceSessionDto] fromJson parsing error: $e');
      print('   JSON data: $json');
      print('   Stack trace: $st');
      rethrow;
    }
  }

  static Map<String, dynamic>? _geoMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Try to parse today's session from GET /attendance/today response.
  /// Backend may return a single session object or flat { punch_in_time, punch_out_time, ... }.
  static AttendanceSessionDto? fromTodayResponse(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;

    // Session-style response
    if (json['id'] != null ||
        json['punch_in_at'] != null ||
        json['punchInAt'] != null) {
      final id = json['id']?.toString() ?? '';
      final employeeId = json['employee_id']?.toString() ??
          json['employeeId']?.toString() ??
          '';
      final workDate = parseServerDateTime(
        json['work_date'] ?? json['workDate'],
        debugLabel: 'work_date',
        isDateOnly: true,
      );
      final punchInAt = parseServerDateTime(
          json['punch_in_at'] ?? json['punchInAt'],
          debugLabel: 'punch_in_at');
      final punchOutAt = parseServerDateTime(
          json['punch_out_at'] ?? json['punchOutAt'],
          debugLabel: 'punch_out_at');
      final status =
          json['status'] as String? ?? (punchOutAt != null ? 'closed' : 'open');
      final remarks = _readRemark(json, [
        'remarks',
        'remark',
        'punch_remark',
        'punchRemark',
        'note',
        'comment',
        'punch_in_remark',
        'punchInRemark',
        'punch_out_remark',
        'punchOutRemark',
        'action_remark',
        'actionRemark',
      ]);
      final punchInGeo = PunchGeoDto.fromJson(
          _geoMap(json['punch_in_geo'] ?? json['punchInGeo']));
      final punchOutGeo = PunchGeoDto.fromJson(
          _geoMap(json['punch_out_geo'] ?? json['punchOutGeo']));
      if (kDebugMode && remarks != null && remarks.trim().isNotEmpty) {
        debugPrint('📋 [Attendance] parsed remarks (today): $remarks');
      }
      return AttendanceSessionDto(
        id: id,
        employeeId: employeeId,
        workDate: workDate,
        punchInAt: punchInAt,
        punchOutAt: punchOutAt,
        status: status,
        remarks: remarks,
        punchInGeo: punchInGeo,
        punchOutGeo: punchOutGeo,
      );
    }

    // Flat response: punch_in_time, punch_out_time, working_hours
    final punchInAt = parseServerDateTime(
        json['punch_in_time'] ?? json['punchInTime'],
        debugLabel: 'punch_in_time');
    final punchOutAt = parseServerDateTime(
        json['punch_out_time'] ?? json['punchOutTime'],
        debugLabel: 'punch_out_time');
    if (punchInAt == null && punchOutAt == null) return null;

    final now = DateTime.now();
    final workDate = DateTime(now.year, now.month, now.day);
    final remarks = _readRemark(json, [
      'remarks',
      'remark',
      'punch_remark',
      'punchRemark',
      'note',
      'comment',
      'punch_in_remark',
      'punchInRemark',
      'punch_out_remark',
      'punchOutRemark',
      'action_remark',
      'actionRemark',
    ]);
    final punchInGeo = PunchGeoDto.fromJson(
        _geoMap(json['punch_in_geo'] ?? json['punchInGeo']));
    final punchOutGeo = PunchGeoDto.fromJson(
        _geoMap(json['punch_out_geo'] ?? json['punchOutGeo']));
    if (kDebugMode && remarks != null && remarks.trim().isNotEmpty) {
      debugPrint('📋 [Attendance] parsed remarks (today flat): $remarks');
    }
    return AttendanceSessionDto(
      id: '',
      employeeId: '',
      workDate: workDate,
      punchInAt: punchInAt,
      punchOutAt: punchOutAt,
      status: punchOutAt != null ? 'closed' : 'open',
      remarks: remarks,
      punchInGeo: punchInGeo,
      punchOutGeo: punchOutGeo,
    );
  }

  static String? _readRemark(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v != null && v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v is num) return v.toString();
    }
    return null;
  }
}
