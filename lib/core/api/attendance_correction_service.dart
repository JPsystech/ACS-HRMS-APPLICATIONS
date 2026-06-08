import 'package:dio/dio.dart';
import 'endpoints.dart';

class AttendanceCorrectionDto {
  AttendanceCorrectionDto({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.requestType,
    required this.date,
    this.requestedPunchIn,
    this.requestedPunchOut,
    required this.reason,
    this.remarks,
    required this.status,
    this.approvedBy,
    this.approvedRole,
    this.approvedByName,
    this.approvedAt,
    this.adminRemarks,
    this.createdAt,
  });
  final int id;
  final int employeeId;
  final String? employeeName;
  final String requestType;
  final DateTime date;
  final DateTime? requestedPunchIn;
  final DateTime? requestedPunchOut;
  final String reason;
  final String? remarks;
  final String status;
  final int? approvedBy;
  final String? approvedRole;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? adminRemarks;
  final DateTime? createdAt;
}

class AttendanceCorrectionService {
  AttendanceCorrectionService({required this.dio});
  final Dio dio;

  Future<void> submit({
    required String requestType,
    required DateTime date,
    DateTime? requestedPunchIn,
    DateTime? requestedPunchOut,
    required String reason,
    String? remarks,
  }) async {
    await dio.post(Endpoints.attendanceCorrections, data: {
      'request_type': requestType,
      'date': date.toIso8601String().split('T').first,
      'requested_punch_in': requestedPunchIn?.toIso8601String(),
      'requested_punch_out': requestedPunchOut?.toIso8601String(),
      'reason': reason,
      'remarks': remarks,
    });
  }

  AttendanceCorrectionDto _mapToDto(Map<String, dynamic> m) {
    return AttendanceCorrectionDto(
      id: (m['id'] as num?)?.toInt() ?? 0,
      employeeId: (m['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: m['employee_name'] as String?,
      requestType: m['request_type'] as String? ?? '',
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      requestedPunchIn: DateTime.tryParse(m['requested_punch_in'] as String? ?? ''),
      requestedPunchOut: DateTime.tryParse(m['requested_punch_out'] as String? ?? ''),
      reason: m['reason'] as String? ?? '',
      remarks: m['remarks'] as String?,
      status: m['status'] as String? ?? 'PENDING',
      approvedBy: (m['approved_by'] as num?)?.toInt(),
      approvedRole: m['approved_role'] as String?,
      approvedByName: m['approved_by_name'] as String?,
      approvedAt: DateTime.tryParse(m['approved_at'] as String? ?? ''),
      adminRemarks: m['admin_remarks'] as String?,
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
    );
  }

  Future<List<AttendanceCorrectionDto>> myRequests() async {
    final response = await dio.get<dynamic>(Endpoints.attendanceCorrectionsMy);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) => _mapToDto(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})).toList();
  }

  Future<List<AttendanceCorrectionDto>> listPendingForApprover() async {
    final response = await dio.get<dynamic>(Endpoints.attendanceCorrections);
    final list = response.data is List ? response.data as List : <dynamic>[];
    return list.map((e) => _mapToDto(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})).toList();
  }
}
