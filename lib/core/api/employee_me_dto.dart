import '../models/role.dart';

/// Current user profile from GET /api/v1/employees/me.
/// API returns snake_case; department, reporting_manager, and role are nested objects.
class EmployeeMeDto {
  const EmployeeMeDto({
    this.id = '',
    this.name = '',
    this.empCode = '',
    this.mobileNumber = '',
    this.departmentName = '',
    this.managerName = '',
    this.roleId = '',
    this.roleName = '',
    this.role = Role.unknown,
    this.wfhEnabled = false,
    this.workMode = '',
    this.dob = '',
    this.profilePhotoUrl = '',
    this.profilePhotoUpdatedAt = '',
  });

  final String id;
  final String name;
  final String empCode;
  final String mobileNumber;
  final String departmentName;
  final String managerName;

  /// Role identifier (from role.id, if present).
  final String roleId;

  /// Role name (from role.name, if present).
  final String roleName;

  /// Role enum representation for easier role-based logic
  final Role role;

  /// Whether WFH is enabled for this role. Defaults to false when missing.
  final bool wfhEnabled;

  /// Work mode (e.g., 'SITE', 'OFFICE', 'REMOTE'). Defaults to empty string.
  final String workMode;
  final String dob;
  final String profilePhotoUrl;
  final String profilePhotoUpdatedAt;

  static EmployeeMeDto fromJson(dynamic v) {
    if (v == null) return const EmployeeMeDto();
    final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final roleObj = m['role'];
    String roleId = '';
    String roleName = '';
    Role parsedRole = Role.unknown;
    bool wfhEnabled = false;
    
    if (roleObj is Map) {
      final r = roleObj.cast<String, dynamic>();
      roleId = _str(r['id']);
      roleName = _str(r['name']);
      parsedRole = Role.fromString(roleName);
      wfhEnabled = _bool(r['wfh_enabled'] ?? r['wfhEnabled']);
    } else if (roleObj is String) {
      // Backward compatibility: role as string
      roleName = _str(roleObj);
      parsedRole = Role.fromString(roleName);
    }

    return EmployeeMeDto(
      id: _str(m['id']),
      name: _str(m['name']),
      empCode: _str(m['emp_code'] ?? m['empCode'] ?? m['employee_code'] ?? m['employeeCode']),
      mobileNumber: _str(m['mobile_number'] ?? m['mobileNumber'] ?? m['mobile'] ?? m['phone'] ?? m['phone_number'] ?? m['phoneNumber']),
      departmentName: _nestedStr(m['department'] ?? m['department_name'] ?? m['departmentName'], 'name'),
      managerName: _nestedStr(m['reporting_manager'] ?? m['reportingManager'] ?? m['manager_name'] ?? m['managerName'] ?? m['manager'], 'name'),
      roleId: roleId,
      roleName: roleName,
      role: parsedRole,
      wfhEnabled: wfhEnabled,
      workMode: _str(m['work_mode'] ?? m['workMode'] ?? m['work_type'] ?? m['workType']),
      dob: _str(m['dob']),
      profilePhotoUrl: _str(m['profile_photo_url'] ?? m['profilePhotoUrl']),
      profilePhotoUpdatedAt: _str(m['profile_photo_updated_at'] ?? m['profilePhotoUpdatedAt']),
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

  /// Read string from nested object (e.g. department.name, reporting_manager.name).
  static String _nestedStr(dynamic v, String key) {
    if (v == null) return '';
    if (v is Map) {
      final inner = (v).cast<String, dynamic>();
      return _str(inner[key]);
    }
    if (v is String) return v.trim();
    if (v is num) return v.toString();
    return '';
  }

  /// Create a copy with updated fields
  EmployeeMeDto copyWith({
    String? id,
    String? name,
    String? empCode,
    String? mobileNumber,
    String? departmentName,
    String? managerName,
    String? roleId,
    String? roleName,
    Role? role,
    bool? wfhEnabled,
    String? workMode,
    String? dob,
    String? profilePhotoUrl,
    String? profilePhotoUpdatedAt,
  }) {
    return EmployeeMeDto(
      id: id ?? this.id,
      name: name ?? this.name,
      empCode: empCode ?? this.empCode,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      departmentName: departmentName ?? this.departmentName,
      managerName: managerName ?? this.managerName,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      role: role ?? this.role,
      wfhEnabled: wfhEnabled ?? this.wfhEnabled,
      workMode: workMode ?? this.workMode,
      dob: dob ?? this.dob,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profilePhotoUpdatedAt: profilePhotoUpdatedAt ?? this.profilePhotoUpdatedAt,
    );
  }
}
