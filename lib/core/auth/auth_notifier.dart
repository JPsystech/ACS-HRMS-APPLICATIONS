import 'package:acs_hrms/core/auth/auth_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';

/// Auth state: token or loading/error. Used for redirect (null → login).
class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier(this._repo, this._onAuthChange, {void Function(bool)? onMustChangePassword})
      : _onMustChangePassword = onMustChangePassword,
        super(const AsyncValue.loading()) {
    _loadToken();
  }

  final AuthService _repo;
  final VoidCallback? _onAuthChange;
  final void Function(bool)? _onMustChangePassword;
  bool _isLoggingOut = false;

  void _log(String msg) {
    if (kDebugMode) {
      debugPrint(msg);
    } else {
      print(msg);
    }
  }

  Future<void> _loadToken() async {
    state = const AsyncValue.loading();
    try {
      final token = await _repo.getStoredToken();
      final rememberMeStr = await _repo.tokenStore.read(AuthConstants.rememberMeKey);
      final rememberMe = rememberMeStr == 'true';
      final refreshToken = await _repo.tokenStore.read(AuthConstants.refreshTokenKey);
      final accessExp = await _repo.tokenStore.read(AuthConstants.accessTokenExpiryKey);
      final refreshExp = await _repo.tokenStore.read(AuthConstants.refreshTokenExpiryKey);

      final hasToken = token != null && token.isNotEmpty;
      final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;
      _log('[AUTH_BOOT] hasToken=$hasToken hasRefresh=$hasRefresh');
      if (!hasToken && !hasRefresh) {
        _log('[AUTH_BOOT] unauthenticated startup, skipping protected preload');
      }

      if (token == null || token.isEmpty) {
        state = const AsyncValue.data(null);
        _onAuthChange?.call();
        return;
      }

      if (!rememberMe) {
        await _repo.forceLocalLogout();
        state = const AsyncValue.data(null);
        _onAuthChange?.call();
        return;
      }

      if (_isExpired(accessExp)) {
        final canRefresh = refreshToken != null && refreshToken.isNotEmpty && !_isExpired(refreshExp);
        if (!canRefresh) {
          await _repo.forceLocalLogout();
          state = const AsyncValue.data(null);
          _onAuthChange?.call();
          return;
        }
        try {
          await _repo.refresh();
        } catch (_) {
          await _repo.forceLocalLogout();
          state = const AsyncValue.data(null);
          _onAuthChange?.call();
          return;
        }
      }

      try {
        await _repo.me();
        final currentToken = await _repo.getStoredToken();
        state = AsyncValue.data(currentToken);
      } catch (_) {
        final canRefresh = refreshToken != null && refreshToken.isNotEmpty && !_isExpired(refreshExp);
        if (!canRefresh) {
          await _repo.forceLocalLogout();
          state = const AsyncValue.data(null);
          _onAuthChange?.call();
          return;
        }
        try {
          await _repo.refresh();
          await _repo.me();
          final currentToken = await _repo.getStoredToken();
          state = AsyncValue.data(currentToken);
        } catch (_) {
          await _repo.forceLocalLogout();
          state = const AsyncValue.data(null);
          _onAuthChange?.call();
          return;
        }
      }
      _onAuthChange?.call();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      _onAuthChange?.call();
    }
  }

  Future<bool> login(String empCode, String password, {bool rememberMe = false}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.login(empCode, password, rememberMe: rememberMe);
      final token = await _repo.getStoredToken();
      state = AsyncValue.data(token);
      _onAuthChange?.call();
      _onMustChangePassword?.call(result.mustChangePassword);
      return result.mustChangePassword;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      await _repo.manualLogout();
    } finally {
      state = const AsyncValue.data(null);
      _onAuthChange?.call();
      _isLoggingOut = false;
    }
  }

  Future<void> manualLogout() => logout();

  Future<void> forceLocalLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      await _repo.forceLocalLogout();
    } finally {
      state = const AsyncValue.data(null);
      _onAuthChange?.call();
      _isLoggingOut = false;
    }
  }

  bool _isExpired(String? iso) {
    if (iso == null) return false;
    final t = DateTime.tryParse(iso);
    if (t == null) return false;
    return t.toUtc().isBefore(DateTime.now().toUtc());
  }
}
