import 'package:flutter/foundation.dart';

/// Config for attendance punch-in/out (GPS, mock location).
class AttendancePunchConfig {
  AttendancePunchConfig._();

  /// Block punch on mock location in release/production builds, but allow it in debug mode for simulator testing.
  static const bool blockPunchOnMockLocation = kReleaseMode;

  /// Max location accuracy (meters) to accept without showing warning. Above this, user can retry.
  static const double maxAccuracyWarningMeters = 50.0;
}
