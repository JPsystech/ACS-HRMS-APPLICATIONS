/// Response for GET /api/v1/compoff/balance.
class CompoffBalanceDto {
  const CompoffBalanceDto({
    this.availableDays = 0,
    this.pendingDays = 0,
    this.usedDays = 0,
  });

  final double availableDays;
  final double pendingDays;
  final double usedDays;

  static CompoffBalanceDto fromJson(dynamic v) {
    if (v == null) return const CompoffBalanceDto();
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    return CompoffBalanceDto(
      availableDays: _num(m['available_days'] ?? m['availableDays'] ?? m['balance'] ?? m['available']) ?? 0,
      pendingDays: _num(m['pending_days'] ?? m['pendingDays'] ?? m['pending']) ?? 0,
      usedDays: _num(m['used_days'] ?? m['usedDays'] ?? m['used']) ?? 0,
    );
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Single comp-off request from GET /api/v1/compoff/my-requests.
class CompoffRequestDto {
  const CompoffRequestDto({
    required this.id,
    required this.dateWorked,
    this.reason = '',
    this.days = 1.0,
    this.status = 'pending',
  });

  final String id;
  final DateTime dateWorked;
  final String reason;
  final double days;
  final String status;

  static CompoffRequestDto? fromJson(dynamic v) {
    if (v == null) return null;
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final date = _date(m['date_worked'] ?? m['dateWorked'] ?? m['worked_date'] ?? m['date']);
    if (date == null) return null;
    return CompoffRequestDto(
      id: m['id']?.toString() ?? m['request_id']?.toString() ?? '',
      dateWorked: date,
      reason: (m['reason'] as String?)?.trim() ?? '',
      days: CompoffBalanceDto._num(m['days'] ?? m['full_day']) ?? (m['half_day'] == true ? 0.5 : 1.0),
      status: (m['status'] as String?)?.toLowerCase() ?? 'pending',
    );
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
