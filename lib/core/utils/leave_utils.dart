import '../api/employee_me_dto.dart';
import '../models/role.dart';

/// Utility functions for leave approval logic
class LeaveUtils {
  LeaveUtils._();

  /// Check if a user can approve leaves based on their role
  /// ADMIN/MD/VP/MANAGER can approve leaves
  /// EMPLOYEE cannot approve leaves
  /// HR is included only if backend allows HR approvals
  static bool canApproveLeaves(EmployeeMeDto? employee) {
    if (employee == null) return false;
    
    final role = employee.role;
    
    // Roles that can approve leaves
    return role == Role.admin ||
           role == Role.md ||
           role == Role.vp ||
           role == Role.manager;
    // Note: HR is intentionally excluded unless backend specifically allows HR approvals
    // To include HR, add: || role == Role.hr
  }

  /// Get the display name for a role in the approval context
  static String getApproverRoleDisplayName(Role role) {
    switch (role) {
      case Role.admin:
        return 'Administrator';
      case Role.md:
        return 'Managing Director';
      case Role.vp:
        return 'Vice President';
      case Role.manager:
        return 'Manager';
      case Role.employee:
        return 'Employee';
      case Role.unknown:
        return 'Unknown Role';
    }
  }

  /// Check if a user should see the pending approvals menu option
  static bool shouldShowPendingApprovals(EmployeeMeDto? employee) {
    return canApproveLeaves(employee);
  }

  /// Get the badge count for pending approvals (placeholder - would need API call)
  /// This is a placeholder that would typically be replaced with actual API data
  static int getPendingApprovalsBadgeCount(EmployeeMeDto? employee) {
    if (!canApproveLeaves(employee)) return 0;
    
    // In a real implementation, this would fetch from an API
    // For now, return 0 - the actual count will come from the pending leaves API
    return 0;
  }
}