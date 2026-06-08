/// Reason for location failure so UI can show the right CTA.
enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  accuracyPoor,
  mockDetected,
  timeout,
  other,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.reason, [this.message]);

  final LocationFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}
