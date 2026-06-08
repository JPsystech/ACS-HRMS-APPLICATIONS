
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:acs_hrms/core/api/attendance_dto.dart';
import '../../core/api/attendance_service.dart';
import '../../core/providers.dart';
import '../dashboard/dashboard_notifier.dart';


/// State for punch in/out action: idle, loading, last result or error message.
class AttendanceActionState {
  const AttendanceActionState({
    this.isLoading = false,
    this.errorMessage,
    this.lastSession,
  });

  final bool isLoading;
  final String? errorMessage;
  final AttendanceSessionDto? lastSession;

  AttendanceActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    AttendanceSessionDto? lastSession,
  }) {
    return AttendanceActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastSession: lastSession ?? this.lastSession,
    );
  }
}

/// Notifier for punch in/out: runs API call, sets loading/error, invalidates today + history on success.
class AttendanceActionNotifier extends StateNotifier<AttendanceActionState> {
  AttendanceActionNotifier(this._ref) : super(const AttendanceActionState());

  final Ref _ref;

  AttendanceService get _service => _ref.read(attendanceServiceProvider);

  Future<void> punchIn({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _service.punchIn(
        deviceId: deviceId,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        capturedAt: capturedAt,
        address: address,
      );
      if (!mounted) return;
      state = state.copyWith(isLoading: false, lastSession: session, errorMessage: null);
      _invalidateAttendance();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('❌ [PunchIn] Dio error: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromDio(e),
      );
      return;
    } catch (e, st) {
      print('❌ [PunchIn] UNKNOWN ERROR: $e');
      print(st);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst(RegExp(r'^Exception: '), ''),
      );
      return;
    }
  }

  Future<void> punchOut({
    required String deviceId,
    double? lat,
    double? lng,
    double? accuracy,
    String? capturedAt,
    String? address,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _service.punchOut(
        deviceId: deviceId,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        capturedAt: capturedAt,
        address: address,
      );
      if (!mounted) return;
      state = state.copyWith(isLoading: false, lastSession: session, errorMessage: null);
      _invalidateAttendance();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('❌ [PunchOut] Dio error: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromDio(e),
      );
      return;
    } catch (e, st) {
      print('❌ [PunchOut] UNKNOWN ERROR: $e');
      print(st);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst(RegExp(r'^Exception: '), ''),
      );
      return;
    }
  }

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(errorMessage: null);
  }

  void _invalidateAttendance() {
    try {
      if (kDebugMode) debugPrint('🔄 [Punch] Invalidating attendance-related providers...');
      _ref.invalidate(todaySessionProvider);
      _ref.invalidate(myAttendanceProvider);
      _ref.invalidate(todayAttendanceProvider);
      _ref.invalidate(dashboardProvider);
      
      // Also specifically refresh dashboard if it's already instantiated
      // This ensures background data updates don't conflict with punch state
      Future.microtask(() {
        try {
          if (_ref.exists(dashboardProvider)) {
            _ref.read(dashboardProvider.notifier).refresh();
          }
        } catch (e) {
          debugPrint('⚠️ [Punch] Dashboard refresh triggered but failed: $e');
        }
      });

      if (kDebugMode) debugPrint('✅ [Punch] Providers invalidated successfully.');
    } catch (e, st) {
      // Never let invalidation failures throw during punch flow
      debugPrint('⚠️ [Punch] Error during _invalidateAttendance: $e');
      debugPrint(st.toString());
    }
  }

  static String _messageFromDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        (e.type == DioExceptionType.unknown &&
            (e.message?.toLowerCase().contains('socket') ?? false))) {
      return 'Check connection';
    }
    final res = e.response;
    if (res != null) {
      final data = res.data;
      if (res.statusCode == 401) return 'Session expired';
      if (res.statusCode == 500 && _isDbMigrationMessage(data)) {
        return 'Server is being updated. Please try again later.';
      }
      if (data is Map) {
        final msg = data['message'] as String? ??
            data['detail'] as String? ??
            data['error'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
        final list = data['errors'] as List?;
        if (list != null && list.isNotEmpty && list.first is String) {
          return list.first as String;
        }
      }
      if (res.statusCode == 400) {
        if (data is Map) {
          final msg = data['message'] as String? ??
              data['detail'] as String? ??
              data['error'] as String?;
          if (msg != null && msg.isNotEmpty) return msg;
        }
        return data?.toString() ?? 'Invalid request';
      }
      if (res.statusCode == 403) return 'Not allowed';
    }
    return e.message ?? 'Something went wrong';
  }

  static bool _isDbMigrationMessage(dynamic data) {
    if (data == null) return false;
    final str = data is Map
        ? ((data['message'] ?? data['detail'] ?? data['error'])?.toString() ?? '')
        : data.toString();
    final lower = str.toLowerCase();
    return lower.contains('migration') || lower.contains('database') || lower.contains('schema');
  }
}

final attendanceActionProvider =
StateNotifierProvider<AttendanceActionNotifier, AttendanceActionState>((ref) {
  return AttendanceActionNotifier(ref);
});
