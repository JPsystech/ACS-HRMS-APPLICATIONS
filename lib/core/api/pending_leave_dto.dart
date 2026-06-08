
import '../utils/server_datetime_util.dart';
import 'api_repository.dart';

/// Pending leave request DTO for GET /api/v1/leaves/pending
/// Includes employee information for approvers to see who requested the leave
class PendingLeaveDto {
  const PendingLeaveDto({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.appliedAt,
    this.status = 'PENDING',
    this.duration = 'FULL_DAY',
    this.halfDaySession,
    this.days,
    this.approvedAt,
    this.approvedRemark,
    this.approvedRole,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedRemark,
    this.rejectedBy,
    this.cancelledAt,
    this.cancelledRemark,
    this.cancelledBy,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String department;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final DateTime appliedAt;
  final String status;
  final String duration;
  final String? halfDaySession;
  final int? days;

  // Action details
  final DateTime? approvedAt;
  final String? approvedRemark;
  final String? approvedRole;
  final LeaveActionBy? approvedBy;
  final DateTime? rejectedAt;
  final String? rejectedRemark;
  final LeaveActionBy? rejectedBy;
  final DateTime? cancelledAt;
  final String? cancelledRemark;
  final LeaveActionBy? cancelledBy;

  /// Number of days between fromDate and toDate (inclusive)
  int get calculatedDays {
    return toDate.difference(fromDate).inDays + 1;
  }

  static PendingLeaveDto? fromJson(dynamic item) {
    if (item == null) return null;
    if (item is! Map<String, dynamic>) return null;
    
    final map = Map<String, dynamic>.from(item);

    // Extract leave request details
    final id = map['id']?.toString() ?? map['leave_id']?.toString();
    if (id == null) return null;

    // Extract employee information from nested employee object or flat fields
    final employeeMap = map['employee'] is Map<String, dynamic> 
        ? Map<String, dynamic>.from(map['employee']) 
        : map;
        
    final employeeName = _readString(employeeMap, ['name', 'employee_name', 'employeeName', 'emp_name', 'full_name']);
    final employeeCode = _readString(employeeMap, ['code', 'employee_code', 'employeeCode', 'emp_code', 'employee_id']);
    final department = _readString(employeeMap, ['department', 'department_name', 'departmentName', 'dept']);

    // Extract leave details
    final leaveType = _readString(map, ['leave_type', 'leaveType', 'type', 'leave_type_name']);
    
    // Extract dates - handle both yyyy-MM-dd format and ISO timestamps
    final fromDate = _readDate(map, ['from_date', 'fromDate', 'start_date', 'startDate']);
    final toDate = _readDate(map, ['to_date', 'toDate', 'end_date', 'endDate']);
    
    // Extract reason and applied timestamp
    final reason = _readString(map, ['reason', 'description', 'purpose']);
    final appliedAt = _readDate(map, ['applied_at', 'appliedAt', 'created_at', 'createdAt', 'requested_at', 'created_date']);
    
    // Extract status and duration
    final status = _readString(map, ['status', 'state', 'leave_status', 'status_code']).toUpperCase();
    final duration = _readString(map, ['duration']).toUpperCase();
    final halfDaySession = _readString(map, ['half_day_session', 'halfDaySession']).toUpperCase();

    // Action details
    final approvedAt = _readDate(map, ['approved_at', 'approvedAt']);
    final approvedRemark = _readString(map, ['approved_remark', 'approvedRemark', 'approve_remark', 'approveRemark', 'action_remark', 'actionRemark']);
    final approvedRole = _readString(map, ['approved_role', 'approvedRole']);
    final approvedBy = LeaveActionBy.fromJson(map['approved_by'] ?? map['approvedBy'] ?? map['approver']);
    
    final rejectedAt = _readDate(map, ['rejected_at', 'rejectedAt']);
    final rejectedRemark = _readString(map, ['rejected_remark', 'rejectedRemark', 'reject_remark', 'rejectRemark', 'action_remark', 'actionRemark']);
    final rejectedBy = LeaveActionBy.fromJson(map['rejected_by'] ?? map['rejectedBy']);
    
    final cancelledAt = _readDate(map, ['cancelled_at', 'cancelledAt']);
    final cancelledRemark = _readString(map, ['cancelled_remark', 'cancelledRemark', 'cancel_remark', 'cancelRemark', 'action_remark', 'actionRemark']);
    final cancelledBy = LeaveActionBy.fromJson(map['cancelled_by'] ?? map['cancelledBy']);

    // Extract days - handle both int and double (computed_days from API contract)
    final days = _readDays(map, ['computed_days', 'days', 'total_days', 'totalDays', 'number_of_days']);

    // Validate required fields
    if (employeeName.isEmpty || employeeCode.isEmpty || 
        leaveType.isEmpty || fromDate == null || toDate == null) {
      return null;
    }

    return PendingLeaveDto(
      id: id,
      employeeName: employeeName,
      employeeCode: employeeCode,
      department: department,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      appliedAt: appliedAt ?? DateTime.now(),
      status: status.isEmpty ? 'PENDING' : status,
      duration: duration.isEmpty ? 'FULL_DAY' : duration,
      halfDaySession: halfDaySession.isEmpty ? null : halfDaySession,
      days: days,
      approvedAt: approvedAt,
      approvedRemark: approvedRemark.isEmpty ? null : approvedRemark,
      approvedRole: approvedRole.isEmpty ? null : approvedRole,
      approvedBy: approvedBy,
      rejectedAt: rejectedAt,
      rejectedRemark: rejectedRemark.isEmpty ? null : rejectedRemark,
      rejectedBy: rejectedBy,
      cancelledAt: cancelledAt,
      cancelledRemark: cancelledRemark.isEmpty ? null : cancelledRemark,
      cancelledBy: cancelledBy,
    );
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static DateTime? _readDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return parseServerDateTime(value);
      }
    }
    return null;
  }


  /// Read days value handling both int and double (computed_days from API contract)
  static int? _readDays(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        if (value is int) return value;
        if (value is double) return value.round(); // Round double to nearest int
        if (value is String) {
          // Try parsing as double first, then int
          final doubleValue = double.tryParse(value);
          if (doubleValue != null) return doubleValue.round();
          return int.tryParse(value);
        }
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'PendingLeaveDto{id: $id, employee: $employeeName ($employeeCode), dept: $department, type: $leaveType, dates: $fromDate to $toDate}';
  }
}

/// Response wrapper for GET /api/v1/leaves/pending
class PendingLeavesResponse {
  const PendingLeavesResponse({
    required this.items,
    required this.total,
  });

  final List<PendingLeaveDto> items;
  final int total;

  static PendingLeavesResponse fromJson(dynamic response) {
    if (response == null) return const PendingLeavesResponse(items: [], total: 0);
    
    final map = response is Map<String, dynamic> 
        ? Map<String, dynamic>.from(response) 
        : <String, dynamic>{};
    
    final rawList = map['items'] ?? map['data'] ?? map['leaves'] ?? [];
    final total = map['total'] ?? map['count'] ?? 0;
    
    final List<PendingLeaveDto> items = [];
    if (rawList is List) {
      for (final item in rawList) {
        final pendingLeave = PendingLeaveDto.fromJson(item);
        if (pendingLeave != null) {
          items.add(pendingLeave);
        }
      }
    }
    
    return PendingLeavesResponse(items: items, total: total is int ? total : 0);
  }
}