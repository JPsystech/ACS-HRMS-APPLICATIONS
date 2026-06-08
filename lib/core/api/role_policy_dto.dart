/// Role policy DTO for WFH and other role-based permissions.
/// This model represents the policy information that should be accessible to all users.
class RolePolicyDto {
  const RolePolicyDto({
    this.wfhEnabled = false,
    this.roleName = '',
    this.roleRank = 999,
  });

  /// Whether WFH is enabled for this role
  final bool wfhEnabled;

  /// Role name for display purposes
  final String roleName;

  /// Role rank for hierarchy comparisons
  final int roleRank;

  /// Parse from JSON response
  static RolePolicyDto fromJson(dynamic v) {
    if (v == null) return const RolePolicyDto();
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    return RolePolicyDto(
      wfhEnabled: _bool(m['wfh_enabled'] ?? m['wfhEnabled']),
      roleName: _str(m['role_name'] ?? m['roleName'] ?? m['role']),
      roleRank: _int(m['role_rank'] ?? m['roleRank']),
    );
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is num) return v.toString();
    return '';
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }
    return false;
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final s = v.trim();
      return int.tryParse(s) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return 'RolePolicyDto{wfhEnabled: \$wfhEnabled, roleName: \$roleName, roleRank: \$roleRank}';
  }
}