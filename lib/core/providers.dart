import 'package:acs_hrms/core/api/pending_leave_dto.dart';
import 'package:acs_hrms/core/utils/leave_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/api_repository.dart';
import 'package:acs_hrms/core/api/attendance_api.dart';
import 'package:acs_hrms/core/api/attendance_dto.dart';
import 'package:acs_hrms/core/api/attendance_service.dart';
import 'api/holiday_service.dart';
import 'api/employee_me_dto.dart';
import 'api/employee_service.dart';
import 'api/leave_balance_dto.dart';
import 'api/leave_policy_dto.dart';
import 'api/compoff_dto.dart';
import 'api/compoff_service.dart';
import 'api/leave_service.dart';
import 'api/role_policy_dto.dart';
import 'api/role_policy_service.dart';
import 'api/wfh_balance_dto.dart';
import 'api/wfh_dto.dart';
import 'api/wfh_service.dart';
import 'api/culture_service.dart';
import 'api/culture_dto.dart';
import 'api/attendance_correction_service.dart';
import 'api/event_service.dart';
import 'api/payslip_dto.dart';
import 'api/payslip_service.dart';
import 'auth/auth_service.dart';
import 'auth/auth_notifier.dart';
import 'storage/secure_store.dart';
import '../features/attendance/punch_session_controller.dart';
import '../features/attendance/punch_session.dart';
import '../features/attendance/today_attendance_notifier.dart';
import '../features/dashboard/dashboard_notifier.dart';
import '../features/leaves/leave_balance_notifier.dart';
import 'notifications/notification_service.dart';
import 'notifications/fcm_service.dart';

/// Notifier for GoRouter redirect when auth changes (e.g. 401 logout).
final authRefreshProvider = Provider<ChangeNotifier>((ref) => _AuthRefreshNotifier());

/// Attendance streak provider (last 30 working days by default)
final attendanceStreakProvider = FutureProvider<AttendanceStreakDto>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) {
    return const AttendanceStreakDto(
      currentStreakDays: 0,
      consistencyPercent: 0,
      windowDays: 0,
      goodDays: 0,
      workDays: 0,
    );
  }
  final service = ref.read(attendanceServiceProvider);
  final holidays = await ref.watch(holidaysProvider.future);
  final leaves = await ref.watch(myLeavesProvider.future);
  
  return service.calculatePunctualityStreak(
    window: 30,
    holidays: holidays,
    leaves: leaves,
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final fcmServiceProvider = Provider<FcmService>((ref) {
  final client = ref.watch(apiClientProvider);
  final store = ref.watch(secureStoreProvider);
  return FcmService(dio: client.dio, secureStore: store);
});

class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Simple auth event counter to broadcast "401 happened" without creating provider cycles.
final authEventProvider = StateProvider<int>((ref) => 0);

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Must-change-password session flag set after login.
final mustChangePasswordProvider = StateProvider<bool>((ref) => false);


final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStore = ref.watch(secureStoreProvider);

  return ApiClient(
    secureStore: secureStore,
    on401: () {
      // Broadcast a 401 event (breaks circular dependency)
      ref.read(authEventProvider.notifier).state++;

      // Also refresh router redirects if you use GoRouter refreshListenable
      (ref.read(authRefreshProvider) as _AuthRefreshNotifier).refresh();
    },
  );
});

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final store = ref.watch(secureStoreProvider);
  return ApiRepository(dio: client.dio, secureStore: store);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  final secureStore = ref.watch(secureStoreProvider);
  return AuthService(dio: client.dio, tokenStore: secureStore);
});

final attendanceApiProvider = Provider<AttendanceApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return AttendanceApi(dio: client.dio);
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final api = ref.watch(attendanceApiProvider);
  return AttendanceService(attendanceApi: api);
});

final leaveServiceProvider = Provider<LeaveService>((ref) {
  final client = ref.watch(apiClientProvider);
  return LeaveService(dio: client.dio);
});

final holidayServiceProvider = Provider<HolidayService>((ref) {
  final client = ref.watch(apiClientProvider);
  return HolidayService(dio: client.dio);
});

final payslipServiceProvider = Provider<PayslipService>((ref) {
  final client = ref.watch(apiClientProvider);
  return PayslipService(dio: client.dio);
});

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  final client = ref.watch(apiClientProvider);
  return EmployeeService(dio: client.dio);
});

/// Role policy service for safely fetching user policy information
final rolePolicyServiceProvider = Provider<RolePolicyService>((ref) {
  final client = ref.watch(apiClientProvider);
  return RolePolicyService(dio: client.dio);
});

/// Current user's role policy (safe for all users, returns null on 403)
final rolePolicyProvider = FutureProvider.autoDispose<RolePolicyDto?>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return null;
  final service = ref.watch(rolePolicyServiceProvider);
  return service.getCurrentUserPolicy();
});

final compoffServiceProvider = Provider<CompoffService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CompoffService(dio: client.dio);
});

final wfhServiceProvider = Provider<WfhService>((ref) {
  final client = ref.watch(apiClientProvider);
  return WfhService(dio: client.dio);
});

final cultureServiceProvider = Provider<CultureService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CultureService(dio: client.dio);
});

final attendanceCorrectionServiceProvider = Provider<AttendanceCorrectionService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AttendanceCorrectionService(dio: client.dio);
});

final myAttendanceCorrectionsProvider = FutureProvider.autoDispose<List<AttendanceCorrectionDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <AttendanceCorrectionDto>[];
  final svc = ref.watch(attendanceCorrectionServiceProvider);
  return svc.myRequests();
});

final pendingAttendanceCorrectionsProvider = FutureProvider.autoDispose<List<AttendanceCorrectionDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <AttendanceCorrectionDto>[];
  final svc = ref.watch(attendanceCorrectionServiceProvider);
  return svc.listPendingForApprover();
});

final eventServiceProvider = Provider<EventService>((ref) {
  final client = ref.watch(apiClientProvider);
  return EventService(dio: client.dio);
});

/// Compoff balance (available days). Invalidate to refresh.
final compoffBalanceProvider =
    FutureProvider.autoDispose<CompoffBalanceDto>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return const CompoffBalanceDto();
  final service = ref.watch(compoffServiceProvider);
  return service.getBalance();
});

/// My comp-off requests. Invalidate to refresh.
final myCompoffRequestsProvider =
    FutureProvider.autoDispose<List<CompoffRequestDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <CompoffRequestDto>[];
  final service = ref.watch(compoffServiceProvider);
  return service.listMyRequests();
});

/// My WFH requests. Invalidate to refresh.
final myWfhProvider =
    FutureProvider.autoDispose<List<WfhRequestDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <WfhRequestDto>[];
  final service = ref.watch(wfhServiceProvider);
  return service.myWfh();
});

/// My WFH balance per year. Invalidate to refresh.
final wfhBalanceProvider =
    FutureProvider.autoDispose.family<WfhBalanceDto, int>((ref, year) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return WfhBalanceDto(year: year);
  final service = ref.watch(wfhServiceProvider);
  return service.getMyWfhBalance(year);
});

/// Pure: no ref.listen here. 401 → logout is handled by auth401ListenerProvider (watch at app root).
final StateNotifierProvider<AuthNotifier, AsyncValue<String?>> authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<String?>>((ref) {
  final repo = ref.watch(authServiceProvider);
  final refresh = ref.read(authRefreshProvider) as _AuthRefreshNotifier;
  final mustChange = ref.read(mustChangePasswordProvider.notifier);
  return AuthNotifier(
    repo,
    refresh.refresh,
    onMustChangePassword: (flag) => mustChange.state = flag,
  );
});

/// Listens to 401 events and triggers logout. Watch at app root (HrmsApp) so it runs. Logout runs in a microtask to avoid provider self-dependency.
final auth401ListenerProvider = Provider<void>((ref) {
  ref.listen<int>(authEventProvider, (prev, next) {
    if (prev != null && prev != next) {
      Future.microtask(() => ref.read(authProvider.notifier).forceLocalLogout());
    }
  });
});

/// Listens to auth and invalidates session/leave/dashboard on logout or login. Watch at app root (HrmsApp). Invalidations run in a microtask to avoid "provider cannot depend on itself" (listener must not synchronously trigger reads of authProvider).
final authStateListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<String?>>(authProvider, (prev, next) {
    next.whenOrNull(
      data: (token) {
        void doInvalidate() {
          if (token == null) {
            ref.invalidate(todaySessionProvider);
            ref.invalidate(dashboardProvider);
            ref.invalidate(todayAttendanceProvider);
            ref.invalidate(myAttendanceProvider);
            ref.invalidate(leaveBalanceProvider);
            ref.invalidate(leaveBalanceSummaryProvider);
            ref.invalidate(leavePolicyProvider);
            ref.invalidate(profileProvider);
            ref.invalidate(compoffBalanceProvider);
            ref.invalidate(myCompoffRequestsProvider);
          } else {
            ref.invalidate(todaySessionProvider);
            ref.invalidate(dashboardProvider);
            // Register/refresh FCM token on login
            final fcm = ref.read(fcmServiceProvider);
            Future.microtask(() => fcm.registerCurrentToken());
          }
        }
        Future.microtask(doInvalidate);
      },
    );
  });
});

/// Initialize FCM as early as possible (app start). Watch at app root.
final fcmInitProvider = Provider<void>((ref) {
  Future.microtask(() => ref.read(fcmServiceProvider).init());
});

/// Punch session (in or out).
final punchSessionProvider =
StateNotifierProvider<PunchSessionController, PunchSession?>(
      (ref) => PunchSessionController(),
);

/// Today's attendance (dashboard card). Can be set from API or after punch.
final todayAttendanceProvider =
StateNotifierProvider<TodayAttendanceNotifier, TodayAttendanceModel>(
      (ref) {
        final token = ref.watch(authProvider).valueOrNull;
        final authed = token != null && token.isNotEmpty;
        return TodayAttendanceNotifier(ref: authed ? ref : null);
      },
);

/// Today's session from GET /attendance/today. Invalidate after punch in/out.
final todaySessionProvider =
    FutureProvider.autoDispose<AttendanceSessionDto?>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return null;
  final service = ref.watch(attendanceServiceProvider);
  return service.getTodaySession();
});

/// My attendance history for date range. Use family (from, to).
final myAttendanceProvider =
    FutureProvider.autoDispose.family<List<AttendanceSessionDto>, (DateTime, DateTime)>((ref, range) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <AttendanceSessionDto>[];
  final service = ref.watch(attendanceServiceProvider);
  return service.getMySessions(range.$1, range.$2);
});

class AttendanceMonthStats {
  const AttendanceMonthStats({
    required this.presentDays,
    required this.missingPunchIn,
    required this.missingPunchOut,
  });

  final int presentDays;
  final int missingPunchIn;
  final int missingPunchOut;

  int get missPunchTotal => missingPunchIn + missingPunchOut;
}

final attendanceMonthStatsThisMonthProvider =
    FutureProvider.autoDispose<AttendanceMonthStats>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  final sessions = await ref.watch(myAttendanceProvider((from, to)).future);

  final todayDate = DateTime(now.year, now.month, now.day);
  final presentKeys = <String>{};
  final missInKeys = <String>{};
  final missOutKeys = <String>{};

  for (final s in sessions) {
    final dt = s.workDate ?? s.punchInAt ?? s.punchOutAt;
    if (dt == null) continue;
    final d = DateTime(dt.year, dt.month, dt.day);
    final key = '${d.year}-${d.month}-${d.day}';

    final missingIn = s.punchInAt == null && s.punchOutAt != null;
    final missingOut = s.punchInAt != null && s.punchOutAt == null;
    final present = s.punchInAt != null && s.punchOutAt != null;

    if (present) {
      presentKeys.add(key);
      continue;
    }

    if (missingIn) missInKeys.add(key);
    if (missingOut && d != todayDate) missOutKeys.add(key);
  }

  return AttendanceMonthStats(
    presentDays: presentKeys.length,
    missingPunchIn: missInKeys.length,
    missingPunchOut: missOutKeys.length,
  );
});

/// Holidays from backend. Invalidate to refresh.
final holidaysProvider =
FutureProvider.autoDispose<List<HolidayDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <HolidayDto>[];
  final service = ref.watch(holidayServiceProvider);
  final public = await service.listHolidays();
  final restricted = await service.listRestrictedHolidays();
  return [...public, ...restricted];
});

final myPayslipsProvider = FutureProvider.autoDispose<List<PayslipDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <PayslipDto>[];
  final service = ref.watch(payslipServiceProvider);
  return service.myPayslips();
});

/// My leaves from backend. Invalidate to refresh.
final myLeavesProvider =
FutureProvider.autoDispose<List<LeaveDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <LeaveDto>[];
  final service = ref.watch(leaveServiceProvider);
  return service.listLeaves();
});

/// Leave balance (wallet) per year. Invalidate on logout; refresh on pull-to-refresh.
final leaveBalanceProvider =
    StateNotifierProvider<LeaveBalanceNotifier, LeaveBalanceState>((ref) {
  final service = ref.watch(leaveServiceProvider);
  final store = ref.watch(secureStoreProvider);
  return LeaveBalanceNotifier(service, store);
});

/// Leave balance summary for dashboard card. GET /leaves/balance/summary/me. Invalidate on refresh.
final leaveBalanceSummaryProvider =
    FutureProvider.autoDispose<LeaveBalanceResponseDto>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  final year = DateTime.now().year;
  if (token == null || token.isEmpty) {
    return LeaveBalanceResponseDto(year: year, items: const []);
  }
  final service = ref.watch(leaveServiceProvider);
  return service.getLeaveBalanceSummary(year);
});

/// Leave policy per year. GET /api/v1/policy/{year}. Invalidate on refresh.
/// Only HR/ADMIN users can access this endpoint. For non-HR users, returns default policy.
final leavePolicyProvider =
    FutureProvider.autoDispose<LeavePolicyDto>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) {
    return LeavePolicyDto(year: DateTime.now().year);
  }
  final service = ref.watch(leaveServiceProvider);
  final year = DateTime.now().year;
  
  // Get current user's role to determine if they can access the policy endpoint
  final profile = ref.watch(profileProvider).valueOrNull;
  final userRole = profile?.role;
  
  return service.getPolicy(year, userRole: userRole);
});

/// Profile (current user) from GET /api/v1/employees/me (EmployeeService). Invalidate on refresh. Only fetches when logged in.
final profileProvider =
    FutureProvider.autoDispose<EmployeeMeDto?>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return null;
  final employeeService = ref.watch(employeeServiceProvider);
  return employeeService.me();
});

/// Pending leave approvals provider - fetches pending leave requests for approvers
final pendingLeavesProvider = FutureProvider.autoDispose<PendingLeavesResponse>((ref) async {
  final service = ref.watch(leaveServiceProvider);
  
  // Wait for profile to ensure we can filter out own requests
  final profile = await ref.watch(profileProvider.future);
  
  // Fetch both pending and all leaves to merge them
  final pendingFuture = service.fetchPendingLeaves();
  final allFuture = service.fetchAllLeavesForApprover();
  
  final responses = await Future.wait([pendingFuture, allFuture]);
  final pendingResponse = responses[0];
  final allResponse = responses[1];
  
  // Merge items, avoiding duplicates (prioritize pending response for details)
  final Map<String, PendingLeaveDto> mergedItems = {};
  
  // 1. Add all from /list (includes approved, rejected, cancelled, and pending)
  for (final item in allResponse.items) {
    // Filter out own leave requests from the approvals list
    if (profile != null && item.employeeCode.trim().toLowerCase() == profile.empCode.trim().toLowerCase()) continue;
    mergedItems[item.id] = item;
  }
  
  // 2. Add/Overwrite with items from /pending (most accurate for "pending" status)
  for (final item in pendingResponse.items) {
    // Filter out own leave requests from the approvals list (backend fix also handles this)
    if (profile != null && item.employeeCode.trim().toLowerCase() == profile.empCode.trim().toLowerCase()) continue;
    mergedItems[item.id] = item;
  }
  
  final itemsList = mergedItems.values.toList();
  
  // Sort: Pending first, then by appliedAt descending
  itemsList.sort((a, b) {
    if (a.status == 'PENDING' && b.status != 'PENDING') return -1;
    if (a.status != 'PENDING' && b.status == 'PENDING') return 1;
    return b.appliedAt.compareTo(a.appliedAt);
  });
  
  return PendingLeavesResponse(
    items: itemsList,
    total: itemsList.length,
  );
});

/// Provider to check if current user can approve leaves
final canApproveLeavesProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return LeaveUtils.canApproveLeaves(profile);
});

/// Provider for pending approvals badge count
final pendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final canApprove = ref.watch(canApproveLeavesProvider);
  if (!canApprove) return 0;
  
  try {
    // Only count truly PENDING leaves for the badge
    final service = ref.watch(leaveServiceProvider);
    
    // Wait for profile to ensure we can filter out own requests
    final profile = await ref.watch(profileProvider.future);
    final pendingLeaves = await service.fetchPendingLeaves();
    
    // Filter out own leave requests from the badge count
    final correctedItems = pendingLeaves.items.where((l) {
      if (profile == null) return true;
      return l.employeeCode.trim().toLowerCase() != profile.empCode.trim().toLowerCase();
    }).toList();
    
    return correctedItems.length;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Failed to fetch pending approvals count: $e');
    }
    return 0;
  }
});

final birthdayThemeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return const <String, dynamic>{};
  final repo = ref.watch(apiRepositoryProvider);
  return repo.themeToday();
});

final birthdaysTodayProvider = FutureProvider.autoDispose<List<BirthdayEmployeeDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <BirthdayEmployeeDto>[];
  final service = ref.watch(cultureServiceProvider);
  return service.birthdaysToday();
});

final birthdaysUpcomingProvider = FutureProvider.autoDispose.family<List<BirthdayEmployeeDto>, int>((ref, days) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <BirthdayEmployeeDto>[];
  final service = ref.watch(cultureServiceProvider);
  return service.birthdaysUpcoming(days);
});

final eventsProvider = FutureProvider.autoDispose<List<CompanyEventDto>>((ref) async {
  final token = ref.watch(authProvider).valueOrNull;
  if (token == null || token.isEmpty) return <CompanyEventDto>[];
  final service = ref.watch(eventServiceProvider);
  return service.listEvents(onlyActive: true);
});
