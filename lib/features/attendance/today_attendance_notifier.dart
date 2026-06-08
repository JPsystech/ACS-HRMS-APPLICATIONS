import 'package:acs_hrms/core/api/attendance_dto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/ist_time.dart';

/// UI-only model for today's attendance (punch in/out in UTC; display in IST).
class TodayAttendanceModel {
  const TodayAttendanceModel({
    this.todayPunchInTime,
    this.todayPunchOutTime,
  });

  final DateTime? todayPunchInTime;
  final DateTime? todayPunchOutTime;

  String get punchInFormatted => IstTime.formatHHmmFromUtc(todayPunchInTime);
  String get punchOutFormatted => IstTime.formatHHmmFromUtc(todayPunchOutTime);

  String get workingHoursText {
    if (todayPunchInTime == null) return '0h 00m';
    final end = todayPunchOutTime ?? DateTime.now().toUtc();
    final diff = end.difference(todayPunchInTime!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  TodayAttendanceModel copyWith({
    DateTime? todayPunchInTime,
    DateTime? todayPunchOutTime,
  }) {
    return TodayAttendanceModel(
      todayPunchInTime: todayPunchInTime ?? this.todayPunchInTime,
      todayPunchOutTime: todayPunchOutTime ?? this.todayPunchOutTime,
    );
  }
}

/// StateNotifier for today's attendance. When punch-in: set punch-in time to now.
/// When punch-out: set punch-out time to now (working duration is computed from state).
/// Can also set from API DTO (dashboard sync).
class TodayAttendanceNotifier extends StateNotifier<TodayAttendanceModel> {
  TodayAttendanceNotifier({Ref? ref}) : super(const TodayAttendanceModel()) {
    // If ref is provided, we can listen to todaySessionProvider to keep this notifier in sync
    // without doing manual fetches in the constructor.
    if (ref != null) {
      _syncWithSession(ref);
    }
  }

  void _syncWithSession(Ref ref) {
    // Listen to todaySessionProvider. When it emits data, update this notifier.
    ref.listen<AsyncValue<AttendanceSessionDto?>>(
      todaySessionProvider,
      (prev, next) {
        next.whenData((session) {
          if (session != null) {
            setFromApi(
              punchInTime: session.punchInAt,
              punchOutTime: session.punchOutAt,
            );
          } else {
            // No session today yet, reset state
            if (mounted) {
              state = const TodayAttendanceModel();
            }
          }
        });
      },
      fireImmediately: true,
    );
  }

  void setPunchIn(DateTime time) {
    if (!mounted) return;
    state = state.copyWith(todayPunchInTime: time);
  }

  void setPunchOut(DateTime time) {
    if (!mounted) return;
    state = state.copyWith(todayPunchOutTime: time);
  }

  /// Set from API response (punch_in_time, punch_out_time). Working hours computed from state.
  void setFromApi({
    DateTime? punchInTime,
    DateTime? punchOutTime,
  }) {
    if (!mounted) return;
    state = TodayAttendanceModel(
      todayPunchInTime: punchInTime,
      todayPunchOutTime: punchOutTime,
    );
  }
}
