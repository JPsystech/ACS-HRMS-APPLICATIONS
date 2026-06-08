import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../storage/secure_store.dart';
import '../auth/auth_constants.dart';
import 'endpoints.dart';

/// Dio client with auth interceptor and 401 handling.
class ApiClient {
  ApiClient({
    required SecureStore secureStore,
    required VoidCallback on401,
    Dio? dio,
  })  : _store = secureStore,
        _on401 = on401,
        _dio = dio ?? Dio(_baseOptions) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip token for refresh and login endpoints if needed, 
          // though typically login doesn't have one and refresh uses refreshToken in body
          
          // Add debug logging
          if (kDebugMode) {
            debugPrint('🌐 API Request: ${options.method} ${options.uri}');
          }
          
          // Add authorization header
          final token = await _store.read(AuthConstants.tokenKey);
          if (token != _lastSeenToken) {
            _lastSeenToken = token;
            _handlingUnauthorized = false;
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          // Log errors in both debug and release mode to identify production network issues
          final method = error.requestOptions.method;
          final path = error.requestOptions.path;
          final status = error.response?.statusCode;
          final errorMsg = '❌ API Error: $method $path -> Status: $status, Message: ${error.message}';
          
          if (kDebugMode) {
            debugPrint(errorMsg);
          } else {
            // In release, print to console for logcat/Sentry debugging
            if (kDebugMode) {
              print(errorMsg);
            }
            if (error.response?.data != null) {
              if (kDebugMode) {
                print('  Response body: ${error.response?.data}');
              }
            }
          }

          if (error.response?.statusCode == 401) {
            final reqPath = error.requestOptions.path;
            final reqUri = error.requestOptions.uri.toString();

            debugPrint('[401_HANDLER] path=$reqPath');

            if (!_shouldHandle401(path: reqPath, uri: reqUri)) {
              debugPrint('[401_HANDLER] skipped auth endpoint');
              handler.next(error);
              return;
            }

            final currentToken = await _store.read(AuthConstants.tokenKey);
            if (currentToken == null || currentToken.isEmpty) {
              handler.next(error);
              return;
            }

            if (_handlingUnauthorized) {
              debugPrint('[401_HANDLER] already handling');
              handler.next(error);
              return;
            }

            final canAttemptRefresh = !_pathMatches(reqPath, Endpoints.authRefresh);
            if (canAttemptRefresh) {
              final refreshToken = await _store.read(AuthConstants.refreshTokenKey);
              final rememberMe =
                  await _store.read(AuthConstants.rememberMeKey) == 'true';

              if (rememberMe && refreshToken != null && refreshToken.isNotEmpty) {
                try {
                  if (kDebugMode) {
                    debugPrint('🔐 401 Unauthorized - attempting token refresh');
                  }

                  final refreshResponse = await _dio.post(
                    Endpoints.authRefresh,
                    data: {'refresh_token': refreshToken},
                    options: Options(validateStatus: (s) => s != null && s < 500),
                  );

                  if (refreshResponse.statusCode == 200) {
                    final data = refreshResponse.data as Map<String, dynamic>;
                    final newToken = data['access_token'] as String;
                    final newRefreshToken = data['refresh_token'] as String?;
                    final accessExpiry = data['access_token_expires_at'] as String?;
                    final refreshExpiry = data['refresh_token_expires_at'] as String?;

                    if (kDebugMode) {
                      debugPrint('✅ Token refresh successful. Storing new tokens.');
                    }

                    await _store.write(AuthConstants.tokenKey, newToken);
                    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
                      await _store.write(AuthConstants.refreshTokenKey, newRefreshToken);
                    }
                    if (accessExpiry != null) {
                      await _store.write(AuthConstants.accessTokenExpiryKey, accessExpiry);
                    }
                    if (refreshExpiry != null) {
                      await _store.write(AuthConstants.refreshTokenExpiryKey, refreshExpiry);
                    }

                    final options = error.requestOptions;
                    options.headers['Authorization'] = 'Bearer $newToken';

                    final retryResponse = await _dio.fetch(options);
                    handler.resolve(retryResponse);
                    return;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('❌ Token refresh failed: $e');
                  }
                }
              }
            }

            _handlingUnauthorized = true;
            if (kDebugMode) {
              debugPrint('🔐 401 Unauthorized - triggering logout callback');
            }
            debugPrint('[401_HANDLER] forceLocalLogout triggered');
            _on401();
          }
          
          handler.next(error);
        },
      ),
    );
  }

  static final BaseOptions _baseOptions = BaseOptions(
    baseUrl: ApiConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 60), // Increased for Render cold starts
    receiveTimeout: const Duration(seconds: 60), // Increased for Render cold starts
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );

  final SecureStore _store;
  final VoidCallback _on401;
  final Dio _dio;
  bool _handlingUnauthorized = false;
  String? _lastSeenToken;

  Dio get dio => _dio;

  bool _shouldHandle401({required String path, required String uri}) {
    if (_pathMatchesAny(path, uri, Endpoints.authLogin)) return false;
    if (_pathMatchesAny(path, uri, 'auth/login-mobile')) return false;
    if (_pathMatchesAny(path, uri, Endpoints.authLogout)) return false;
    if (_pathMatchesAny(path, uri, Endpoints.authRefresh)) return false;
    return true;
  }

  bool _pathMatchesAny(String path, String uri, String endpoint) {
    return _pathMatches(path, endpoint) || _pathMatches(uri, endpoint);
  }

  bool _pathMatches(String value, String endpoint) {
    final v = value.toLowerCase();
    final e = endpoint.toLowerCase();
    if (v == e) return true;
    if (v.endsWith('/$e')) return true;
    if (v.contains('/$e')) return true;
    return v.contains(e);
  }

  /// Health check for debugging connectivity
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'health',
        options: Options(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      if (kDebugMode) {
        print('✅ Health check successful: ${response.statusCode}');
      }
      return response.data ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Health check failed: $e');
      }
      rethrow;
    }
  }

  /// Test authentication by calling profile endpoint (Endpoints.profile).
  Future<Map<String, dynamic>> testAuth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(Endpoints.profile);
      if (kDebugMode) {
        print('✅ Auth test successful: ${response.statusCode}');
      }
      return response.data ?? {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auth test failed: $e');
      }
      rethrow;
    }
  }

  /// Get current configuration info for debugging
  Map<String, dynamic> getConfigInfo() {
    return {
      'baseUrl': _baseOptions.baseUrl,
      'apiBaseUrl': ApiConfig.apiBaseUrl,
      'platform': defaultTargetPlatform.toString(),
      'isWeb': kIsWeb,
    };
  }
}
