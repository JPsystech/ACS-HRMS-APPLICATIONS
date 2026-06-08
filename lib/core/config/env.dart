import 'api_config.dart';

/// Multi-environment configuration for API base URL.
/// Supports: Android Emulator, Web Dev, Real Device Dev, and Production
class Env {
  const Env._();

  /// Base URL for backend with smart defaults based on platform
  static String get apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  /// Print environment configuration for debugging
  static void logConfig() {
    ApiConfig.printConfig();
  }
}
