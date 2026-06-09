library;

import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static String _stripApiV1Suffix(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    while (u.toLowerCase().endsWith('/api/v1')) {
      u = u.substring(0, u.length - '/api/v1'.length);
      while (u.endsWith('/')) {
        u = u.substring(0, u.length - 1);
      }
    }

    return u;
  }

  /// Get the base URL based on the current platform and environment
  static String get baseUrl {
    // Check for override from dart-define
    const String dartDefineUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      final stripped = _stripApiV1Suffix(dartDefineUrl);
      return _ensureTrailingSlash(stripped);
    }

    // Platform-specific defaults
    if (kIsWeb) {
      // For web, use current hostname or fallback to localhost
      return _getWebBaseUrl();
    } else {
      // For mobile platforms
      return _getMobileBaseUrl();
    }
  }

  static String _getWebBaseUrl() {
    // In web environment, try to use current hostname
    try {
      // This will work in browser environment
      final hostname = _getWindowLocationHostname();
      if (hostname != null && hostname.isNotEmpty) {
        return 'http://$hostname:8001';
      }
    } catch (e) {
      // Fall through to default
    }

    // Fallback for web
    return 'http://127.0.0.1:8001';
  }

  static String? _getWindowLocationHostname() {
    try {
      // This works in browser environment
      return Uri.base.host;
    } catch (e) {
      return null;
    }
  }

  static String _getMobileBaseUrl() {
    if (kReleaseMode) {
      return 'https://acs-hrms-backend.onrender.com';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8001';
    }

    return 'http://192.168.1.15:8001';
    // return 'http://10.151.208.217:8001';
    // return 'http://192.168.1.11:8001';
  }

  static String _ensureTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url;
    }
    return '$url/';
  }

  /// Get the full API base URL including /api/v1 prefix
  static String get apiBaseUrl {
    final root = _stripApiV1Suffix(baseUrl);
    if (root.isEmpty) return 'http://127.0.0.1:8001/api/v1/';
    return '${_ensureTrailingSlash(root)}api/v1/';
  }

  /// Debug method to print current configuration
  static void printConfig() {
    final configStr = 'API Configuration:\n'
        '  Base URL: $baseUrl\n'
        '  API Base URL: $apiBaseUrl\n'
        '  Platform: $defaultTargetPlatform\n'
        '  Is Web: $kIsWeb\n'
        '  Build Mode: ${kReleaseMode ? "Release" : kDebugMode ? "Debug" : "Profile"}';

    if (kDebugMode) {
      debugPrint(configStr);
      const dartDefineUrl = String.fromEnvironment('API_BASE_URL');
      if (dartDefineUrl.isNotEmpty) {
        debugPrint('  Dart Define Override: $dartDefineUrl');
      }
    } else {
      // In release mode, use print so it shows up in logcat/console
      if (kDebugMode) {
        print('🚀 $configStr');
      }
      const dartDefineUrl = String.fromEnvironment('API_BASE_URL');
      if (dartDefineUrl.isNotEmpty) {
        if (kDebugMode) {
          print('  ⚠️ Dart Define Override: $dartDefineUrl');
        }
      }
    }
  }
}
