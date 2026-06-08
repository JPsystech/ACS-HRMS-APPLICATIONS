/// Config for attendance punch-in/out (GPS, mock location).
class AttendancePunchConfig {
  AttendancePunchConfig._();

  /// If true, block punch when mock location is detected. If false, send is_mocked: true and let backend mark suspicious.
  static const bool blockPunchOnMockLocation = true;

  /// Max location accuracy (meters) to accept without showing warning. Above this, user can retry.
  static const double maxAccuracyWarningMeters = 50.0;
}
