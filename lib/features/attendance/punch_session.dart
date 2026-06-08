/// UI-only model for a single punch-in or punch-out session.
/// Holds location, face capture token, and timestamps until punch is submitted.
class PunchSession {
  const PunchSession({
    required this.isPunchIn,
    required this.startedAt,
    this.faceImagePath,
    this.lat,
    this.lng,
    this.accuracy,
    this.locationCapturedAt,
  });

  /// `true` for punch-in, `false` for punch-out.
  final bool isPunchIn;

  /// When the session was started (user chose Punch In or Punch Out).
  final DateTime startedAt;

  /// Placeholder path or token for face capture (e.g. "captured"); use Uint8List? later if needed.
  final String? faceImagePath;

  final double? lat;
  final double? lng;
  final double? accuracy;

  /// When location was last captured.
  final DateTime? locationCapturedAt;

  bool get isFaceCaptured => faceImagePath != null && faceImagePath!.isNotEmpty;

  bool get isLocationCaptured => lat != null && lng != null && accuracy != null;

  PunchSession copyWith({
    bool? isPunchIn,
    DateTime? startedAt,
    String? faceImagePath,
    double? lat,
    double? lng,
    double? accuracy,
    DateTime? locationCapturedAt,
  }) {
    return PunchSession(
      isPunchIn: isPunchIn ?? this.isPunchIn,
      startedAt: startedAt ?? this.startedAt,
      faceImagePath: faceImagePath ?? this.faceImagePath,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracy: accuracy ?? this.accuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
    );
  }
}
