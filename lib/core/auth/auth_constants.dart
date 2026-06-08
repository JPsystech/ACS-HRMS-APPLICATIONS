/// Keys for auth-related secure storage.
abstract final class AuthConstants {
  AuthConstants._();

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String accessTokenExpiryKey = 'access_token_expiry';
  static const String refreshTokenExpiryKey = 'refresh_token_expiry';
  static const String rememberMeKey = 'remember_me';
}
