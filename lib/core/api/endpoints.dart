/// API endpoint path constants.
abstract final class Endpoints {
  Endpoints._();

  static const String authLogin = 'auth/login';
  static const String authLogout = 'auth/logout';
  static const String authRefresh = 'auth/refresh';
  static const String authChangePassword = 'auth/change-password';
  /// Current user profile (name, emp_code, role, department).
  static const String authMe = 'auth/me';
  /// Profile fetch. Use /employees/me (Swagger: GET /api/v1/employees/me).
  static const String profile = 'employees/me';
  /// Alias for profile; used by EmployeeService.
  static const String employeesMe = 'employees/me';

  static const String attendancePunchIn = 'attendance/punch-in';
  static const String attendancePunchOut = 'attendance/punch-out';
  static const String todayAttendance = 'attendance/today';
  static const String attendanceMy = 'attendance/my';
  static const String attendanceList = 'attendance/list';
  static const String attendanceStreak = 'attendance/streak';

  static const String holidays = 'holidays';
  static const String restrictedHolidays = 'restricted-holidays';
  static const String calendarsHolidays = 'calendars/holidays';
  static const String calendarsRestrictedHolidays = 'calendars/restricted-holidays';
  static const String events = 'events';

  static const String leavesList = 'leaves/list';
  static const String leavesMy = 'leaves/my';
  static const String applyLeave = 'leaves/apply';
  static const String leaveBalanceMe = 'leaves/balance/me';
  static const String leaveBalanceSummaryMe = 'leaves/balance/summary/me';
  /// GET /api/v1/policy/{year} — leave policy per year (PL, CL, SL, RH, public_holidays).
  static const String policy = 'policy';

  static const String compoffRequest = 'compoff/request';
  static const String compoffMyRequests = 'compoff/my-requests';

  static const String cultureThemeToday = 'culture/theme/today';
  static const String birthdaysToday = 'culture/birthdays/today';
  static const String birthdaysUpcoming = 'culture/birthdays/upcoming';
  static String generateGreeting(String employeeId) => 'culture/birthday/$employeeId/generate-greeting';
  static String sendWish(String employeeId) => 'culture/birthday/$employeeId/send-wish';
  static String listWishes(String employeeId) => 'culture/birthday/$employeeId/wishes';
  static String replyWish(String wishId) => 'culture/birthday/wishes/$wishId/reply';
  static const String meProfileUpdate = 'me/profile';
  static const String meProfilePhoto = 'me/profile-photo';
  static const String compoffBalance = 'compoff/balance';
  static const String compoffPending = 'compoff/pending';
  static String compoffApprove(String requestId) => 'compoff/$requestId/approve';
  static String compoffReject(String requestId) => 'compoff/$requestId/reject';

  /// WFH endpoints.
  /// POST /api/v1/wfh/apply
  static const String wfhApply = 'wfh/apply';

  /// GET /api/v1/wfh/my
  static const String wfhMy = 'wfh/my';

  /// GET /api/v1/wfh/pending (admin only; not used in mobile app for now).
  static const String wfhPending = 'wfh/pending';

  /// GET /api/v1/wfh/balance/me?year=YYYY
  static const String wfhBalanceMe = 'wfh/balance/me';

  /// Leave approval endpoints
  /// GET /api/v1/leaves/pending - pending leave requests for approvers
  static const String leavesPending = 'leaves/pending';
  static const String attendanceCorrections = 'attendance-corrections';
  static const String attendanceCorrectionsMy = 'attendance-corrections/my';
  
  /// POST /api/v1/leaves/{id}/approve - approve a leave request
  static String leaveApprove(String leaveId) => 'leaves/$leaveId/approve';
  
  /// POST /api/v1/leaves/{id}/reject - reject a leave request
  static String leaveReject(String leaveId) => 'leaves/$leaveId/reject';

  /// PUT /api/v1/leaves/{id} - update a pending leave request (self-edit)
  static String leaveUpdate(String leaveId) => 'leaves/$leaveId';

  /// POST /api/v1/leaves/{id}/cancel - cancel an approved leave request (admin/manager)
  static String leaveCancel(String leaveId) => 'leaves/$leaveId/cancel';

  /// Notifications
  static const String notificationsRegisterDevice = 'notifications/register-device';
  static const String notificationsTest = 'notifications/test';

  static const String payrollMyPayslips = 'payroll/my-payslips';
  static String payrollPayslipDownload(String id) => 'payroll/payslips/$id/download';
}
