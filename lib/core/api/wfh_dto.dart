/// Single WFH request from GET /api/v1/wfh/my.
class WfhRequestDto {
  const WfhRequestDto({
    required this.id,
    this.fromDate,
    this.toDate,
    this.date,
    this.reason = '',
    this.status = 'pending',
    this.createdAt,
    this.decidedAt,
    this.approver,
    this.approvedByName,
    this.approvedRole,
    this.approvalRemark,
  });

  /// Unique identifier for the WFH request.
  final String id;

  /// Start date for WFH (when backend supports range).
  final DateTime? fromDate;

  /// End date for WFH (when backend supports range).
  final DateTime? toDate;

  /// Single date field (when backend sends only one date).
  final DateTime? date;

  /// Employee's reason for requesting WFH.
  final String reason;

  /// Raw status from backend (pending/approved/rejected/cancelled/...).
  final String status;

  /// When the request was created.
  final DateTime? createdAt;

  /// When the request was decided (approved/rejected).
  final DateTime? decidedAt;

  /// Approver display name (or emp code) if available.
  final String? approver;

  /// Approver name from backend object
  final String? approvedByName;

  /// Approver role.
  final String? approvedRole;

  /// Approval/Rejection remark.
  final String? approvalRemark;

  /// Factory to build DTO from dynamic JSON with snake_case / camelCase keys.
  static WfhRequestDto? fromJson(dynamic v) {
    if (v == null) return null;
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final id = (m['id'] ?? m['request_id'] ?? m['wfh_id'])?.toString() ?? '';
    if (id.isEmpty) return null;

    DateTime? date(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toLocal();
      if (value is String) {
        // Try ISO or yyyy-MM-dd
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toLocal();
      }
      if (value is num) {
        // Treat as timestamp (seconds or ms)
        final millis = value > 10000000000 ? value.toInt() : value.toInt() * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      }
      return null;
    }

    String str(dynamic value) {
      if (value == null) return '';
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString();
      return '';
    }

    String? nestedName(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.trim().isEmpty ? null : value.trim();
      if (value is num) return value.toString();
      if (value is Map) {
        final map = value.cast<String, dynamic>();
        final name = str(map['name'] ?? map['employee_name'] ?? map['employeeName']);
        final code = str(map['emp_code'] ?? map['empCode'] ?? map['employee_code']);
        if (name.isEmpty && code.isEmpty) return null;
        if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
        return name.isNotEmpty ? name : code;
      }
      return null;
    }

    final fromDate = date(m['from_date'] ?? m['fromDate'] ?? m['start_date'] ?? m['startDate']);
    final toDate = date(m['to_date'] ?? m['toDate'] ?? m['end_date'] ?? m['endDate']);
    // Backend for apply uses request_date; map it to [date] so UI can display it.
    final singleDate = date(m['date'] ?? m['request_date'] ?? m['requestDate']);

    final createdAt = date(m['created_at'] ?? m['createdAt']);
    final decidedAt = date(m['decided_at'] ?? m['decidedAt'] ?? m['action_at'] ?? m['actionAt'] ?? m['approved_at'] ?? m['approvedAt']);
    final approvedRole = str(m['approved_role'] ?? m['approvedRole']);
    final approvalRemark = str(m['approval_remark'] ?? m['approvalRemark'] ?? m['remarks']);

    final rawStatus = str(m['status'] ?? m['state'] ?? m['wfh_status']);
    final status = rawStatus.isEmpty ? 'unknown' : rawStatus.toLowerCase();

    final approver = nestedName(
      m['approver'] ??
          m['approved_by'] ??
          m['approvedBy'] ??
          m['action_by'] ??
          m['actionBy'],
    );

    // Explicitly map name from approved_by object for cleaner display in UI
    final approvedByJson = m['approved_by'] ?? m['approvedBy'];
    String? approvedByName;
    if (approvedByJson is Map) {
      approvedByName = str(approvedByJson['name'] ?? approvedByJson['employee_name']);
    }

    return WfhRequestDto(
      id: id,
      fromDate: fromDate,
      toDate: toDate,
      date: singleDate,
      reason: str(m['reason'] ?? m['description']),
      status: status,
      createdAt: createdAt,
      decidedAt: decidedAt,
      approver: approver,
      approvedByName: approvedByName?.isEmpty == true ? null : approvedByName,
      approvedRole: approvedRole.isEmpty ? null : approvedRole,
      approvalRemark: approvalRemark.isEmpty ? null : approvalRemark,
    );
  }

  /// Primary "from" date to show in UI.
  DateTime? get primaryFrom => date ?? fromDate;

  /// Primary "to" date to show in UI.
  DateTime? get primaryTo => date ?? toDate ?? fromDate;
}

