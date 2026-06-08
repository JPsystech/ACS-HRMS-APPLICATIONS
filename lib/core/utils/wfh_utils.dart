import 'package:flutter/foundation.dart';
import 'package:acs_hrms/core/api/role_policy_dto.dart';

import '../api/employee_me_dto.dart';

/// Centralized utility for WFH visibility and permission logic.
class WfhUtils {
  /// Determines if WFH should be visible for the given employee.
  /// 
  /// Rule: WFH is visible ONLY when work_mode == OFFICE
  /// If employee is SITE/ONSITE then WFH module must be hidden (not disabled).
  /// 
  /// This is the single source-of-truth for WFH visibility.
  static bool canSeeWFH(EmployeeMeDto? employee) {
    if (employee == null) return false;
    
    final workMode = employee.workMode.toUpperCase();
    
    // WFH is visible ONLY for OFFICE work mode
    final isVisible = workMode == 'OFFICE';
    _logDebug('WFH visibility: $isVisible (work_mode=$workMode)');
    return isVisible;
  }
  
  /// Gets the appropriate error message when WFH is not available.
  /// 
  /// Returns:
  /// - "WFH is not available for Site work mode." if work mode is SITE/ONSITE
  /// - "WFH is not available." for other cases
  static String getWfhErrorMessage(EmployeeMeDto? employee) {
    if (employee == null) return 'WFH is not available.';
    
    final workMode = employee.workMode.toUpperCase();
    
    // Work mode restrictions
    if (workMode == 'SITE' || workMode == 'ONSITE') {
      return 'WFH is not available for Site work mode.';
    }
    
    // Generic message for other cases
    return 'WFH is not available.';
  }
  
  /// Checks if the employee is a Site employee (work mode is SITE or ONSITE).
  static bool isSiteEmployee(EmployeeMeDto? employee) {
    if (employee == null) return false;
    final workMode = employee.workMode.toUpperCase();
    return workMode == 'SITE' || workMode == 'ONSITE';
  }
  
  /// Legacy method for backward compatibility
  static bool canUseWfh(EmployeeMeDto? employee) {
    return canSeeWFH(employee);
  }
  
  /// Debug logging for WFH visibility decisions
  static void _logDebug(String message) {
    assert(() {
      if (kDebugMode) {
        debugPrint('🔍 [WfhUtils] $message');
      }
      return true;
    }());
  }
  
  /// Debug method to log all WFH-related information
  static void debugWfhInfo(EmployeeMeDto? employee, RolePolicyDto? policy) {
    assert(() {
      if (kDebugMode) {
        if (employee == null) {
          debugPrint('🔍 [WfhUtils] Employee: null');
          return true;
        }
        
        debugPrint('🔍 [WfhUtils] Debug Info:');
        debugPrint('  👤 Employee: ${employee.name}');
        debugPrint('  🏢 Work Mode: ${employee.workMode}');
        debugPrint('  👔 Role: ${employee.roleName} (${employee.role.backendValue})');
        debugPrint('  🎯 Role Rank: ${employee.role.rank}');
        debugPrint('  📋 Legacy wfhEnabled: ${employee.wfhEnabled}');
        
        if (policy != null) {
          debugPrint('  📊 Policy wfhEnabled: ${policy.wfhEnabled}');
          debugPrint('  📊 Policy roleName: ${policy.roleName}');
          debugPrint('  📊 Policy roleRank: ${policy.roleRank}');
        } else {
          debugPrint('  📊 Policy: null (not available or not fetched)');
        }
        
        final canSee = canSeeWFH(employee);
        debugPrint('  👁️  canSeeWFH: $canSee');
        debugPrint('  💬 Error Message: "${getWfhErrorMessage(employee)}"');
      }
      
      return true;
    }());
  }
}