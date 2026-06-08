/// Leave policy per year from GET /api/v1/policy/{year}.
/// Fallback defaults: PL=7, CL=5, SL=6, RH=1, publicHolidays=14.
class LeavePolicyDto {
  const LeavePolicyDto({
    required this.year,
    this.pl = 7,
    this.cl = 5,
    this.sl = 6,
    this.rh = 1,
    this.publicHolidays = 14,
  });

  final int year;
  final int pl;
  final int cl;
  final int sl;
  final int rh;
  final int publicHolidays;

  static LeavePolicyDto fromJson(dynamic v, {int? year}) {
    final y = year ?? DateTime.now().year;
    if (v == null) return LeavePolicyDto(year: y);
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    return LeavePolicyDto(
      year: _int(m['year']) ?? y,
      pl: _int(m['pl'] ?? m['PL'] ?? m['paid_leave']) ?? 7,
      cl: _int(m['cl'] ?? m['CL'] ?? m['casual_leave']) ?? 5,
      sl: _int(m['sl'] ?? m['SL'] ?? m['sick_leave']) ?? 6,
      rh: _int(m['rh'] ?? m['RH'] ?? m['restricted_holiday']) ?? 1,
      publicHolidays: _int(m['public_holidays'] ?? m['publicHolidays'] ?? m['company_holidays']) ?? 14,
    );
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
