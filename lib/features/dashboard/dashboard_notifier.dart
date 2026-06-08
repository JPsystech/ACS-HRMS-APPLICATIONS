import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'dashboard_state.dart';

/// Dashboard notifier that fetches all required data for the dashboard
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this.ref) : super(const DashboardState()) {
    ref.listen<AsyncValue<String?>>(
      authProvider,
      (prev, next) {
        final token = next.valueOrNull;
        if (token == null || token.isEmpty) {
          if (mounted) state = const DashboardState();
          return;
        }
        _loadDashboardData();
      },
      fireImmediately: true,
    );
  }

  final Ref ref;

  /// Load all dashboard data from APIs
  Future<void> loadDashboardData() async {
    final token = ref.read(authProvider).valueOrNull;
    if (token == null || token.isEmpty) return;
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchUserProfile(),
        _fetchTodayAttendance(),
        _fetchHolidays(),
        _fetchRestrictedHolidays(),
        _fetchPendingCounts(),
      ], eagerError: true);

      // Update state with all fetched data
      final attendanceData = results[1] as Map<String, DateTime?>;
      state = state.copyWith(
        employeeName: results[0] as String,
        punchInTime: attendanceData['punchIn'],
        punchOutTime: attendanceData['punchOut'],
        totalHolidays: results[2] as int,
        totalRestrictedHolidays: results[3] as int,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: error);
      }
    }
  }

  /// Internal method for loading dashboard data with mounted check
  Future<void> _loadDashboardData() async {
    final token = ref.read(authProvider).valueOrNull;
    if (token == null || token.isEmpty) return;
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchUserProfile(),
        _fetchTodayAttendance(),
        _fetchHolidays(),
        _fetchRestrictedHolidays(),
        _fetchPendingCounts(),
      ], eagerError: true);

      // Check if notifier is still mounted before updating state
      if (!mounted) return;

      // Update state with all fetched data
      final attendanceData = results[1] as Map<String, DateTime?>;
      state = state.copyWith(
        employeeName: results[0] as String,
        punchInTime: attendanceData['punchIn'],
        punchOutTime: attendanceData['punchOut'],
        totalHolidays: results[2] as int,
        totalRestrictedHolidays: results[3] as int,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      // Check if notifier is still mounted before updating state
      if (!mounted) return;
      
      // LOG dashboard refresh failure for debugging but don't show snackbar
      if (kDebugMode) {
        debugPrint('⚠️ Dashboard background refresh failed: $error');
      } else {
        print('⚠️ Dashboard background refresh failed: $error');
      }
      
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  /// Fetch user profile data from /api/v1/auth/me
  Future<String> _fetchUserProfile() async {
    try {
      final authService = ref.read(authServiceProvider);
      final userData = await authService.me();
      return userData['name'] as String? ??
          userData['full_name'] as String? ??
          userData['employee_name'] as String? ??
          'Employee';
    } catch (e) {
      if (mounted) {
        print('Failed to fetch user profile: $e');
      }
      return 'Employee';
    }
  }

  /// Fetch today's attendance from /api/v1/attendance/today
  Future<Map<String, DateTime?>> _fetchTodayAttendance() async {
    try {
      final attendanceService = ref.read(attendanceServiceProvider);
      final todayAttendance = await attendanceService.today();
      return {
        'punchIn': todayAttendance.punchInTime,
        'punchOut': todayAttendance.punchOutTime,
      };
    } catch (e) {
      if (mounted) {
        print('Failed to fetch today attendance: $e');
      }
      return {'punchIn': null, 'punchOut': null};
    }
  }

  /// Fetch holidays from /api/v1/calendars/holidays
  Future<int> _fetchHolidays() async {
    try {
      final holidayService = ref.read(holidayServiceProvider);
      final holidays = await holidayService.listHolidays();
      return holidays.length;
    } catch (e) {
      if (mounted) {
        print('Failed to fetch holidays: $e');
      }
      return 0;
    }
  }

  /// Fetch restricted holidays from /api/v1/calendars/restricted-holidays
  Future<int> _fetchRestrictedHolidays() async {
    try {
      final holidayService = ref.read(holidayServiceProvider);
      final restrictedHolidays = await holidayService.listRestrictedHolidays();
      return restrictedHolidays.length;
    } catch (e) {
      if (mounted) {
        print('Failed to fetch restricted holidays: $e');
      }
      return 0;
    }
  }

  /// Fetch pending leaves and approvals counts
  Future<int> _fetchPendingCounts() async {
    // Placeholder - would need additional API endpoints
    // For now, return 0 as the UI shows 0
    return 0;
  }

  /// Refresh all dashboard data
  Future<void> refresh() async {
    await loadDashboardData();
  }
}

/// Provider for dashboard notifier
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(ref),
);
