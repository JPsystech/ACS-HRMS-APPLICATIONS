/// Result of a live GPS capture for punch-in/out.
class LiveLocationResult {
  const LiveLocationResult({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.timestamp,
    required this.isMocked,
    this.altitude,
    this.heading,
    this.speed,
    this.address,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;
  final double? altitude;
  final double? heading;
  final double? speed;
  final String? address;
}
