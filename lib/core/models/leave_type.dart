/// Single source of truth for leave types: UI label + backend apiValue.
/// Always send [apiValue] in API payloads (e.g. COMPOFF not "Comp-Off").
enum LeaveType {
  cl('CL', 'CL'),
  pl('PL', 'PL'),
  sl('SL', 'SL'),
  rh('RH', 'RH'),
  fl('FL', 'FL'),
  compOff('Comp-Off', 'COMPOFF'),
  lwp('LWP', 'LWP');

  const LeaveType(this.label, this.apiValue);
  final String label;
  final String apiValue;

  /// Backend string (e.g. "COMPOFF", "CL") to enum. Matches apiValue first, then label.
  static LeaveType fromBackend(String? v) {
    if (v == null || v.trim().isEmpty) return LeaveType.cl;
    final u = v.trim().toUpperCase();
    for (final t in LeaveType.values) {
      if (t.apiValue.toUpperCase() == u || t.label.toUpperCase() == u) return t;
    }
    return LeaveType.cl;
  }
}
