/// Single leave type balance (CL/SL/PL/RH).
class LeaveBalanceDto {
  const LeaveBalanceDto({
    required this.leaveType,
    this.totalEntitlement = 0.0,
    this.opening = 0.0,
    this.accrued = 0.0,
    this.used = 0.0,
    this.remaining = 0.0,
    this.eligible = true,
    this.notes,
  });

  final String leaveType;
  final double totalEntitlement;
  final double opening;
  final double accrued;
  final double used;
  final double remaining;
  final bool eligible;
  final String? notes;

  /// Parses items[] from GET /api/v1/leaves/balance/me: leave_type, total_entitlement, used, remaining.
  static LeaveBalanceDto? fromJson(dynamic v) {
    if (v == null) return null;
    final m = _map(v);
    if (m == null) return null;
    final leaveType = _str(m['leave_type'] ?? m['leaveType'] ?? m['type']);
    if (leaveType.isEmpty) return null;
    // Backend sends total_entitlement; support camelCase and aliases.
    final total = _double(m['total_entitlement'] ?? m['totalEntitlement'] ?? m['total'] ?? m['entitled']) ?? 0.0;
    final used = _double(m['used'] ?? m['consumed']) ?? 0.0;
    var remaining = _double(m['remaining'] ?? m['available']) ?? 0.0;
    // If API sends only remaining, derive used from total when possible
    final totalEntitlement = total;
    double usedVal = used;
    if (totalEntitlement > 0 && usedVal == 0.0 && remaining >= 0.0) {
      usedVal = (totalEntitlement - remaining).clamp(0.0, totalEntitlement).toDouble();
    }
    return LeaveBalanceDto(
      leaveType: leaveType,
      totalEntitlement: totalEntitlement,
      opening: _double(m['opening']) ?? 0.0,
      accrued: _double(m['accrued']) ?? 0.0,
      used: usedVal,
      remaining: remaining,
      eligible: m['eligible'] == false ? false : true,
      notes: _str(m['notes']).isEmpty ? null : _str(m['notes']),
    );
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is num) return v.toString();
    return '';
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Response for GET /leaves/balance/me?year=YYYY.
class LeaveBalanceResponseDto {
  const LeaveBalanceResponseDto({
    required this.year,
    required this.items,
  });

  final int year;
  final List<LeaveBalanceDto> items;

  static LeaveBalanceResponseDto fromJson(dynamic v) {
    if (v is List) {
      final items = <LeaveBalanceDto>[];
      for (final e in v) {
        final dto = LeaveBalanceDto.fromJson(e);
        if (dto != null) items.add(dto);
      }
      return LeaveBalanceResponseDto(year: DateTime.now().year, items: items);
    }
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final year = LeaveBalanceDto._int(m['year']) ?? DateTime.now().year;
    final rawList = m['items'] ?? m['data'] ?? m['balances'] ?? m['balance'] ?? [];
    final list = rawList is List ? rawList : <dynamic>[];
    final items = <LeaveBalanceDto>[];
    for (final e in list) {
      final dto = LeaveBalanceDto.fromJson(e);
      if (dto != null) items.add(dto);
    }
    return LeaveBalanceResponseDto(year: year, items: items);
  }
}
