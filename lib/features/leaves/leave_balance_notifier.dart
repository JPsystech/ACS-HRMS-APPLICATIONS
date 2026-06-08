import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_constants.dart';
import '../../core/api/leave_balance_dto.dart';
import '../../core/api/leave_service.dart';
import '../../core/storage/secure_store.dart';

/// State for leave balance (per year).
class LeaveBalanceState {
  const LeaveBalanceState({
    this.year,
    this.data,
    this.loading = false,
    this.error,
  });

  final int? year;
  final LeaveBalanceResponseDto? data;
  final bool loading;
  final Object? error;

  LeaveBalanceState copyWith({
    int? year,
    LeaveBalanceResponseDto? data,
    bool? loading,
    Object? error,
  }) {
    return LeaveBalanceState(
      year: year ?? this.year,
      data: data ?? this.data,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// Notifier for leave balance. Caches per year; refresh reloads current year.
class LeaveBalanceNotifier extends StateNotifier<LeaveBalanceState> {
  LeaveBalanceNotifier(this._service, this._store) : super(const LeaveBalanceState()) {
    // Always fetch latest balance when notifier is created.
    // This ensures mobile matches admin dashboard on first load.
    load(_currentYear);
  }

  final LeaveService _service;
  final SecureStore _store;

  int get _currentYear => DateTime.now().year;

  /// Load balance for [year]. Uses cache if already loaded (call refresh to force reload).
  Future<void> load(int year) async {
    final token = await _store.read(AuthConstants.tokenKey);
    if (token == null || token.isEmpty) return;
    if (!mounted) return;

    state = state.copyWith(loading: true, error: null, year: year);
    try {
      final response = await _service.getLeaveBalance(year);
      if (!mounted) return;
      state = state.copyWith(data: response, loading: false, error: null);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Refresh balance for current year (or last loaded year).
  Future<void> refresh() async {
    final year = state.year ?? _currentYear;
    await load(year);
  }

  /// Ensure current year is loaded (e.g. on first access).
  Future<void> loadIfNeeded() async {
    if (state.data != null && state.year == _currentYear && !state.loading) return;
    await load(_currentYear);
  }
}
