import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/endpoints.dart';
import '../storage/secure_store.dart';
import '../auth/auth_constants.dart';

class AuthService {
  AuthService({required this.dio, required this.tokenStore});

  final Dio dio;
  final SecureStore tokenStore;

  void _log(String msg) {
    if (kDebugMode) {
      debugPrint(msg);
    } else {
      print(msg);
    }
  }

  Future<LoginResult> login(String empCode, String password, {bool rememberMe = false}) async {
    final response = await dio.post<Map<String, dynamic>>(
      Endpoints.authLogin,
      data: {'emp_code': empCode, 'password': password},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    final data = response.data ?? <String, dynamic>{};
    final token = data['access_token'] as String? ?? data['token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final accessExpiry = data['access_token_expires_at'] as String?;
    final refreshExpiry = data['refresh_token_expires_at'] as String?;

    if (token == null || token.isEmpty) throw Exception('No token in response');
    
    // Store tokens and expiry
    await tokenStore.write(AuthConstants.tokenKey, token);
    await tokenStore.write(AuthConstants.rememberMeKey, rememberMe.toString());
    
    if (rememberMe && refreshToken != null) {
      await tokenStore.write(AuthConstants.refreshTokenKey, refreshToken);
    } else {
      await tokenStore.delete(AuthConstants.refreshTokenKey);
    }
    
    if (accessExpiry != null) {
      await tokenStore.write(AuthConstants.accessTokenExpiryKey, accessExpiry);
    }
    if (refreshExpiry != null) {
      await tokenStore.write(AuthConstants.refreshTokenExpiryKey, refreshExpiry);
    }

    final mustChange = (data['must_change_password'] as bool?) ??
        (data['mustChangePassword'] as bool?) ??
        false;
    return LoginResult(mustChangePassword: mustChange);
  }

  Future<void> refresh() async {
    final refreshToken = await tokenStore.read(AuthConstants.refreshTokenKey);
    if (refreshToken == null) throw Exception('No refresh token available');

    final response = await dio.post<Map<String, dynamic>>(
      Endpoints.authRefresh,
      data: {'refresh_token': refreshToken},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final newToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String?;
      final accessExpiry = data['access_token_expires_at'] as String?;
      final refreshExpiry = data['refresh_token_expires_at'] as String?;

      await tokenStore.write(AuthConstants.tokenKey, newToken);
      if (newRefreshToken != null) {
        await tokenStore.write(AuthConstants.refreshTokenKey, newRefreshToken);
      }
      if (accessExpiry != null) {
        await tokenStore.write(AuthConstants.accessTokenExpiryKey, accessExpiry);
      }
      if (refreshExpiry != null) {
        await tokenStore.write(AuthConstants.refreshTokenExpiryKey, refreshExpiry);
      }
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// Current user profile (name, emp_code, role, department). Uses Endpoints.profile (/auth/me).
  Future<Map<String, dynamic>> me() async {
    final path = Endpoints.profile;
    if (kDebugMode) {
      print('🔐 [Profile] GET path: $path');
    }
    final response = await dio.get<Map<String, dynamic>>(path);
    final body = response.data ?? <String, dynamic>{};
    if (kDebugMode) {
      final resolvedUrl = response.requestOptions.uri.toString();
      debugPrint('🔐 [Profile] resolved URL: $resolvedUrl');
      debugPrint('🔐 [Profile] response ${response.statusCode}');
    }
    return body;
  }

  Future<void> manualLogout() async {
    _log('[LOGOUT] manualLogout called');
    try {
      await dio.post(
        Endpoints.authLogout,
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } on DioException {
    } catch (_) {
    }
    await tokenStore.deleteAll();
  }

  Future<void> forceLocalLogout() async {
    _log('[LOGOUT] forceLocalLogout called');
    await tokenStore.deleteAll();
  }

  Future<void> logout() => manualLogout();

  Future<String?> getStoredToken() => tokenStore.read(AuthConstants.tokenKey);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      Endpoints.authChangePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }
}

class LoginResult {
  const LoginResult({required this.mustChangePassword});
  final bool mustChangePassword;
}
