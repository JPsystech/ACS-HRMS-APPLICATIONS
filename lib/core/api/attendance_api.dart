import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:acs_hrms/core/api/attendance_dto.dart';
import '../utils/server_datetime_util.dart';
import 'endpoints.dart';

/// Attendance HTTP API. Uses Dio with Bearer token (via ApiClient interceptor).
/// Logs request URL, status code and response body in debug mode only.
class AttendanceApi {
  AttendanceApi({required this.dio});

  final Dio dio;

  static const String _logTag = '[Attendance]';

  void _logRequest(String method, String path, [Map<String, dynamic>? query, dynamic body]) {
    if (!kDebugMode) return;
    final uri = path;
    final q = query != null && query.isNotEmpty ? '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}' : '';
    debugPrint('$_logTag $method $uri$q');
    if (body != null) debugPrint('$_logTag Request body: $body');
  }

  void _logResponse(int? statusCode, dynamic body) {
    if (kDebugMode) {
      debugPrint('$_logTag Response status: $statusCode');
      if (body != null) debugPrint('$_logTag Response body: $body');
    } else if (statusCode != 200 && statusCode != 201) {
      // In production, log non-success responses to help debug issues
      if (kDebugMode) {
        print('$_logTag Response status: $statusCode');
      }
      if (body != null) print('$_logTag Response body: $body');
    }
  }

  /// POST /api/v1/attendance/punch-in. Sends JSON body: device_id, geo (lat, lng, accuracy, provider, captured_at) or null. Content-Type: application/json.
  Future<AttendanceSessionDto> punchIn({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) async {
    final body = _punchBody(
      deviceId: deviceId,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      capturedAt: capturedAt,
      address: address,
    );
    final jsonBody = jsonEncode(body);
    _logPunchPayload('punch-in', jsonBody, lat: lat, lng: lng, accuracy: accuracy);
    _logRequest('POST', Endpoints.attendancePunchIn, null, jsonBody);

    try {
      final response = await dio.post<Map<String, dynamic>>(
        Endpoints.attendancePunchIn,
        data: jsonBody,
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      _logResponse(response.statusCode, response.data);

      try {
        final parsed = _parseSessionResponse(response.data, isPunchOut: false);
        return parsed;
      } catch (e, st) {
        if (kDebugMode) {
          print('❌ [AttendanceApi] PARSING ERROR in punchIn: $e');
        }
        if (kDebugMode) {
          print('   Response data: ${response.data}');
        }
        if (kDebugMode) {
          print('   Stack trace: $st');
        }
        // Ensure we throw a descriptive error for the notifier
        throw Exception('Response parsing failed: $e');
      }
    } catch (e) {
      if (e is DioException) {
        print('❌ [AttendanceApi] DIO ERROR in punchIn: ${e.type} - ${e.message}');
        if (e.response != null) {
          print('   Status: ${e.response?.statusCode}');
          print('   Data: ${e.response?.data}');
        }
      } else {
        print('❌ [AttendanceApi] UNKNOWN ERROR in punchIn: $e');
      }
      rethrow;
    }
  }

  /// POST /api/v1/attendance/punch-out. Same JSON payload and Content-Type.
  Future<AttendanceSessionDto> punchOut({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) async {
    final body = _punchBody(
      deviceId: deviceId,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      capturedAt: capturedAt,
      address: address,
    );
    final jsonBody = jsonEncode(body);
    _logPunchPayload('punch-out', jsonBody, lat: lat, lng: lng, accuracy: accuracy);
    _logRequest('POST', Endpoints.attendancePunchOut, null, jsonBody);

    try {
      final response = await dio.post<Map<String, dynamic>>(
        Endpoints.attendancePunchOut,
        data: jsonBody,
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      _logResponse(response.statusCode, response.data);

      try {
        final parsed = _parseSessionResponse(response.data, isPunchOut: true);
        return parsed;
      } catch (e, st) {
        print('❌ [AttendanceApi] PARSING ERROR in punchOut: $e');
        print('   Response data: ${response.data}');
        print('   Stack trace: $st');
        // Ensure we throw a descriptive error for the notifier
        throw Exception('Response parsing failed: $e');
      }
    } catch (e) {
      if (e is DioException) {
        print('❌ [AttendanceApi] DIO ERROR in punchOut: ${e.type} - ${e.message}');
        if (e.response != null) {
          print('   Status: ${e.response?.statusCode}');
          print('   Data: ${e.response?.data}');
        }
      } else {
        print('❌ [AttendanceApi] UNKNOWN ERROR in punchOut: $e');
      }
      rethrow;
    }
  }

  /// Request body exactly as backend expects: source, device_id (string), geo (object or null) with lat, lng, accuracy, provider, captured_at.
  static Map<String, dynamic> _punchBody({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) {
    final effectiveDeviceId = deviceId.trim().isEmpty ? 'unknown' : deviceId.trim();
    final Map<String, dynamic>? geo;
    if (lat != null && lng != null && capturedAt != null && capturedAt.isNotEmpty) {
      final g = <String, dynamic>{
        'lat': lat.toDouble(),
        'lng': lng.toDouble(),
        'provider': 'gps',
        'captured_at': capturedAt,
      };
      if (accuracy != null && accuracy > 0) {
        g['accuracy'] = accuracy.toDouble();
      }
      if (address != null && address.trim().isNotEmpty) {
        g['address'] = address.trim();
      }
      geo = g;
    } else {
      geo = null;
    }
    return <String, dynamic>{
      'source': 'MOBILE',
      'device_id': effectiveDeviceId,
      'geo': geo,
    };
  }

  /// Log outgoing payload with jsonEncode so device logs show exact JSON sent to backend.
  static void _logPunchPayload(String action, String jsonBody, {double? lat, double? lng, double? accuracy}) {
    if (!kDebugMode) return;
    debugPrint('$_logTag [DEBUG] $action — lat: $lat, lng: $lng, accuracy: $accuracy');
    debugPrint('$_logTag [DEBUG] $action outgoing payload (jsonEncode):\n$jsonBody');
  }

  /// GET /attendance/today. Returns today's session or null.
  Future<AttendanceSessionDto?> getToday() async {
    _logRequest('GET', Endpoints.todayAttendance);
    final response = await dio.get<Map<String, dynamic>>(Endpoints.todayAttendance);
    _logResponse(response.statusCode, response.data);
    return AttendanceSessionDto.fromTodayResponse(response.data);
  }

  /// GET /attendance/my?from=YYYY-MM-DD&to=YYYY-MM-DD. Uses local date only; to is sent as +1 day if backend treats it as exclusive.
  Future<List<AttendanceSessionDto>> getMy({DateTime? from, DateTime? to}) async {
    final fromLocal = from != null ? DateTime(from.year, from.month, from.day) : null;
    final toLocal = to != null ? DateTime(to.year, to.month, to.day) : null;
    final query = <String, String>{};
    if (fromLocal != null) query['from'] = fmtDate(fromLocal);
    if (toLocal != null) {
      // Backend often treats 'to' as exclusive; send toDate + 1 day so we get sessions through toLocal inclusive.
      query['to'] = fmtDate(toLocal.add(const Duration(days: 1)));
    }
    final uri = query.isEmpty
        ? Endpoints.attendanceMy
        : '${Endpoints.attendanceMy}?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    if (kDebugMode) {
      debugPrint('$_logTag [History] GET $uri  (from=${fromLocal?.toIso8601String().split('T').first}, toInclusive=${toLocal?.toIso8601String().split('T').first})');
    }
    _logRequest('GET', Endpoints.attendanceMy, query.isNotEmpty ? query : null);
    final response = await dio.get<dynamic>(
      Endpoints.attendanceMy,
      queryParameters: query.isNotEmpty ? query : null,
    );
    _logResponse(response.statusCode, response.data);
    final list = _parseListResponse(response.data);
    if (kDebugMode) {
      debugPrint('$_logTag [History] response length: ${list.length} session(s)');
    }
    return list;
  }

  /// ISO date YYYY-MM-DD for query params (local date only).
  static String fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// GET /attendance/list. Optional from/to as query params if backend supports.
  Future<List<AttendanceSessionDto>> list({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = _dateOnly(from);
    if (to != null) query['to'] = _dateOnly(to);
    _logRequest('GET', Endpoints.attendanceList, query.isNotEmpty ? query : null);
    final response = await dio.get<dynamic>(
      Endpoints.attendanceList,
      queryParameters: query.isNotEmpty ? query : null,
    );
    _logResponse(response.statusCode, response.data);
    return _parseListResponse(response.data);
  }

  /// GET /attendance/streak?window=30
  Future<AttendanceStreakDto> getStreak({int window = 30}) async {
    final query = {'window': window};
    _logRequest('GET', Endpoints.attendanceStreak, query);
    final response = await dio.get<Map<String, dynamic>>(
      Endpoints.attendanceStreak,
      queryParameters: query,
    );
    _logResponse(response.statusCode, response.data);
    return AttendanceStreakDto.fromJson(response.data ?? const {});
  }

  static String _dateOnly(DateTime d) => fmtDate(d);

  static List<AttendanceSessionDto> _parseListResponse(dynamic data) {
    List<dynamic> raw = const [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final map = data as Map<String, dynamic>;
      raw = (map['data'] ?? map['sessions'] ?? map['items'] ?? map['results'] ?? map['attendance']) is List
          ? (map['data'] ?? map['sessions'] ?? map['items'] ?? map['results'] ?? map['attendance']) as List<dynamic>
          : const [];
    }
    return raw.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      try {
        return AttendanceSessionDto.fromJson(m);
      } catch (err) {
        if (kDebugMode) {
          debugPrint('⚠️ [AttendanceApi] Error parsing session in list: $err');
          debugPrint('   Raw map: $m');
        }
        // Return a dummy session to avoid breaking the whole list
        final now = DateTime.now();
        return AttendanceSessionDto(
          id: m['id']?.toString() ?? '',
          employeeId: '',
          workDate: DateTime(now.year, now.month, now.day),
        );
      }
    }).toList();
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) {
      // If it's a small int (like 1740464434), it's likely seconds, not milliseconds.
      // 10^10 is a safe threshold for the next ~250 years.
      if (v < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    }
    return null;
  }

  static AttendanceSessionDto _parseSessionResponse(Map<String, dynamic>? data, {required bool isPunchOut}) {
    if (data == null) {
      final now = DateTime.now();
      return AttendanceSessionDto(
        id: '',
        employeeId: '',
        workDate: DateTime(now.year, now.month, now.day),
        punchInAt: isPunchOut ? null : now,
        punchOutAt: isPunchOut ? now : null,
        status: isPunchOut ? 'closed' : 'open',
        remarks: null,
      );
    }

    // Try finding the session object first
    final sessionMap = data['session'] as Map<String, dynamic>? ??
                       data['data'] as Map<String, dynamic>? ??
                       data['attendance'] as Map<String, dynamic>?;

    if (sessionMap != null) {
      return AttendanceSessionDto.fromJson(sessionMap);
    }

    // Check if the current data object is the session itself
    if (data['id'] != null ||
        data['punch_in_at'] != null || data['punchInAt'] != null ||
        data['punch_in_time'] != null || data['punchInTime'] != null) {
      return AttendanceSessionDto.fromJson(data);
    }

    // Last resort: manual parsing
    final now = DateTime.now();
    return AttendanceSessionDto(
      id: data['id']?.toString() ?? '',
      employeeId: data['employee_id']?.toString() ?? data['employeeId']?.toString() ?? '',
      workDate: parseServerDateTime(data['work_date'] ?? data['workDate'], isDateOnly: true) ?? DateTime(now.year, now.month, now.day),
      punchInAt: _parseTime(data['punch_in_at'] ?? data['punchInAt'] ?? data['punch_in_time'] ?? data['punchInTime']) ?? (isPunchOut ? null : now),
      punchOutAt: _parseTime(data['punch_out_at'] ?? data['punchOutAt'] ?? data['punch_out_time'] ?? data['punchOutTime']) ?? (isPunchOut ? now : null),
      status: data['status'] as String? ?? (isPunchOut ? 'closed' : 'open'),
      remarks: data['remarks'] as String?,
    );
  }
}
