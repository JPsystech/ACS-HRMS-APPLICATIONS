import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/auth_constants.dart';
import '../storage/secure_store.dart';
import '../utils/server_datetime_util.dart';
import 'endpoints.dart';

/// API: auth, punch, today attendance, holidays, leaves.
class ApiRepository {
  ApiRepository({
    required this.dio,
    required this.secureStore,
  });

  final Dio dio;
  final SecureStore secureStore;

  /// POST /api/v1/auth/login
  Future<String> login(String empCode, String password, {bool rememberMe = false}) async {
    final response = await dio.post<Map<String, dynamic>>(
      Endpoints.authLogin,
      data: {'emp_code': empCode, 'password': password},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, type: DioExceptionType.unknown);
    final token = data['access_token'] as String? ?? data['token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final accessExpiry = data['access_token_expires_at'] as String?;
    final refreshExpiry = data['refresh_token_expires_at'] as String?;

    if (token == null || token.isEmpty) throw Exception('No token in response');
    
    // Store tokens and metadata
    await secureStore.write(AuthConstants.tokenKey, token);
    await secureStore.write(AuthConstants.rememberMeKey, rememberMe.toString());
    
    if (rememberMe && refreshToken != null) {
      await secureStore.write(AuthConstants.refreshTokenKey, refreshToken);
    } else {
      await secureStore.delete(AuthConstants.refreshTokenKey);
    }
    
    if (accessExpiry != null) {
      await secureStore.write(AuthConstants.accessTokenExpiryKey, accessExpiry);
    }
    if (refreshExpiry != null) {
      await secureStore.write(AuthConstants.refreshTokenExpiryKey, refreshExpiry);
    }

    return token;
  }

  /// GET current user profile (uses Endpoints.profile: /auth/me or /employees/me).
  Future<Map<String, dynamic>> me() async {
    final response = await dio.get<Map<String, dynamic>>(Endpoints.profile);
    return response.data ?? <String, dynamic>{};
  }

  Future<void> logout() async {
    try {
      await dio.post(
        Endpoints.authLogout,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (_) {}
    await secureStore.deleteAll();
  }

  Future<Map<String, dynamic>> themeToday() async {
    final response = await dio.get<Map<String, dynamic>>(Endpoints.cultureThemeToday);
    return response.data ?? <String, dynamic>{};
    }

  Future<String?> getStoredToken() async {
    return secureStore.read(AuthConstants.tokenKey);
  }

  /// POST /api/v1/attendance/punch-in|punch-out multipart: face_image, lat, lng, accuracy.
  Future<void> punch({
    required bool isPunchIn,
    required String faceImagePath,
    required double lat,
    required double lng,
    required double accuracy,
  }) async {
    final file = File(faceImagePath);
    if (!await file.exists()) throw Exception('Face image file not found');
    final formData = FormData.fromMap({
      'face_image': await MultipartFile.fromFile(file.path, filename: 'face.jpg'),
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
    });
    final path = isPunchIn ? Endpoints.attendancePunchIn : Endpoints.attendancePunchOut;
    await dio.post(path, data: formData);
  }

  /// GET /api/v1/attendance/today
  Future<TodayAttendanceDto> getTodayAttendance() async {
    final response = await dio.get<Map<String, dynamic>>(Endpoints.todayAttendance);
    final data = response.data ?? {};
    return TodayAttendanceDto(
      punchInTime: parseServerDateTime(data['punch_in_time'] ?? data['punch_in_at']),
      punchOutTime: parseServerDateTime(data['punch_out_time'] ?? data['punch_out_at']),
      workingHoursText: data['working_hours'] as String? ?? '0h 00m',
    );
  }

  static DateTime? _parseTime(dynamic v) {
    return parseServerDateTime(v);
  }

  /// GET /api/v1/holidays
  Future<List<HolidayDto>> getHolidays() async {
    final response = await dio.get<dynamic>(Endpoints.holidays);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return HolidayDto(
        date: _parseTime(m['date']) ?? DateTime.now(),
        name: m['name'] as String? ?? '',
        type: (m['type'] as String? ?? 'public') == 'restricted' ? 'restricted' : 'public',
        description: m['description'] as String? ?? '',
        imageUrl: m['image_url'] as String?,
      );
    }).toList();
  }

  static String? _readLeaveRemark(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v != null && v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v is num) return v.toString();
    }
    return null;
  }

  static String _normalizeLeaveStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'unknown';
    final s = raw.trim().toLowerCase().replaceAll('canceled', 'cancelled');
    if (s.contains('cancel')) return 'cancelled';
    if (s.contains('approve')) return 'approved';
    if (s.contains('reject')) return 'rejected';
    if (s.contains('pending')) return 'pending';
    return s;
  }

  /// GET /api/v1/leaves/list — returns all statuses (pending, approved, rejected, cancelled). Do not filter.
  Future<List<LeaveDto>> getLeaves() async {
    final response = await dio.get<dynamic>(Endpoints.leavesList);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final rawStatus = m['status']?.toString() ?? m['state']?.toString() ?? m['leave_status']?.toString() ?? '';
      return LeaveDto(
        id: m['id']?.toString() ?? m['leave_id']?.toString(),
        leaveType: m['leave_type'] as String? ?? 'CL',
        fromDate: parseServerDateTime(m['from_date']) ?? DateTime.now(),
        toDate: parseServerDateTime(m['to_date']) ?? DateTime.now(),
        reason: m['reason'] as String? ?? '',
        status: _normalizeLeaveStatus(rawStatus.isEmpty ? null : rawStatus),
        appliedAt: parseServerDateTime(m['applied_at'] ?? m['appliedAt'] ?? m['created_at'] ?? m['createdAt']),
        approvedRemark: _readLeaveRemark(m, ['approved_remark', 'approvedRemark', 'approve_remark', 'approveRemark', 'approver_remark', 'approverRemark', 'approval_remark', 'approvalRemark', 'action_remark', 'actionRemark']),
        rejectedRemark: _readLeaveRemark(m, ['rejected_remark', 'rejectedRemark', 'reject_remark', 'rejectRemark', 'action_remark', 'actionRemark']),
        cancelledRemark: _readLeaveRemark(m, ['cancelled_remark', 'cancelledRemark', 'cancel_remark', 'cancelRemark', 'action_remark', 'actionRemark']),
        approvedAt: parseServerDateTime(m['approved_at'] ?? m['approvedAt']),
        rejectedAt: parseServerDateTime(m['rejected_at'] ?? m['rejectedAt']),
        cancelledAt: parseServerDateTime(m['cancelled_at'] ?? m['cancelledAt']),
        approvedBy: LeaveActionBy.fromJson(m['approved_by'] ?? m['approvedBy']),
        rejectedBy: LeaveActionBy.fromJson(m['rejected_by'] ?? m['rejectedBy']),
        cancelledBy: LeaveActionBy.fromJson(m['cancelled_by'] ?? m['cancelledBy']),
      );
    }).toList();
  }

  /// POST /api/v1/leaves/apply
  Future<void> applyLeave({
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    await dio.post(Endpoints.applyLeave, data: {
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().split('T').first,
      'to_date': toDate.toIso8601String().split('T').first,
      'reason': reason,
    });
  }
}

class TodayAttendanceDto {
  TodayAttendanceDto({
    this.punchInTime,
    this.punchOutTime,
    this.workingHoursText = '0h 00m',
  });
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final String workingHoursText;
}

class HolidayDto {
  HolidayDto({required this.date, required this.name, required this.type, this.description = '', this.imageUrl});
  final DateTime date;
  final String name;
  final String type;
  final String description;
  final String? imageUrl;
}

/// Who performed an action (e.g. approved_by, rejected_by).
class LeaveActionBy {
  const LeaveActionBy({this.name, this.empCode});
  final String? name;
  final String? empCode;

  String get displayLabel {
    if (name != null && name!.isNotEmpty) {
      if (empCode != null && empCode!.isNotEmpty) return '$name ($empCode)';
      return name!;
    }
    if (empCode != null && empCode!.isNotEmpty) return empCode!;
    return '—';
  }

  static LeaveActionBy? fromJson(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) {
      final name = v['name'] as String? ?? v['employee_name'] as String?;
      final empCode = v['emp_code'] as String? ?? v['empCode'] as String? ?? v['employee_code'] as String?;
      if (name == null && empCode == null) return null;
      return LeaveActionBy(name: name, empCode: empCode);
    }
    if (v is String && v.isNotEmpty) return LeaveActionBy(name: v, empCode: null);
    return null;
  }
}

class LeaveDto {
  LeaveDto({
    this.id,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.duration,
    this.halfDaySession,
    this.approvedRemark,
    this.approvedRole,
    this.rejectedRemark,
    this.cancelledRemark,
    this.approvedAt,
    this.rejectedAt,
    this.cancelledAt,
    this.appliedAt,
    this.approvedBy,
    this.rejectedBy,
    this.cancelledBy,
  });
  final String? id;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status;
  final String? duration;
  final String? halfDaySession;
  final String? approvedRemark;
  final String? approvedRole;
  final String? rejectedRemark;
  final String? cancelledRemark;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;
  final DateTime? appliedAt;
  final LeaveActionBy? approvedBy;
  final LeaveActionBy? rejectedBy;
  final LeaveActionBy? cancelledBy;
}
