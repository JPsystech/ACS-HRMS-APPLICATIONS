import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/api/attendance_correction_service.dart';

final attendanceCorrectionActionProvider = StateNotifierProvider<AttendanceCorrectionActionNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(attendanceCorrectionServiceProvider);
  return AttendanceCorrectionActionNotifier(service, ref);
});

class AttendanceCorrectionActionNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceCorrectionActionNotifier(this._service, this._ref) : super(const AsyncData(null));

  final AttendanceCorrectionService _service;
  final Ref _ref;

  Future<void> approveCorrection(int reqId, String? adminRemarks) async {
    state = const AsyncLoading();
    try {
      await _service.approveCorrection(reqId, adminRemarks);
      state = const AsyncData(null);
      // Invalidate the list to trigger a refresh
      _ref.invalidate(pendingAttendanceCorrectionsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> rejectCorrection(int reqId, String? adminRemarks) async {
    state = const AsyncLoading();
    try {
      await _service.rejectCorrection(reqId, adminRemarks);
      state = const AsyncData(null);
      // Invalidate the list to trigger a refresh
      _ref.invalidate(pendingAttendanceCorrectionsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
