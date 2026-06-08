/// WFH balance for a given year from GET /api/v1/wfh/balance/me?year=YYYY.
class WfhBalanceDto {
  const WfhBalanceDto({
    required this.year,
    this.accrued = 0,
    this.used = 0,
    this.remaining = 0,
    this.entitled = 0,
  });

  final int year;
  final double accrued;
  final double used;
  final double remaining;
  final double entitled;

  static WfhBalanceDto fromJson(dynamic v) {
    if (v == null) {
      final currentYear = DateTime.now().year;
      return WfhBalanceDto(year: currentYear);
    }
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    int parseInt(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    final currentYear = DateTime.now().year;

    return WfhBalanceDto(
      year: parseInt(m['year'], currentYear),
      accrued: parseNum(m['accrued'] ?? m['earned']),
      used: parseNum(m['used']),
      remaining: parseNum(m['remaining'] ?? m['balance']),
      entitled: parseNum(m['entitled'] ?? m['total'] ?? m['limit']),
    );
  }
}
