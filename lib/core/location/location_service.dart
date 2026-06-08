import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

import 'live_location_result.dart';
import 'location_exception.dart';

/// Max accuracy (meters) to accept without warning. Above this, UI can show warning and retry.
const double kLocationAccuracyWarningThresholdMeters = 50.0;

class LocationService {
  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission (whileInUse). Returns true if granted.
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Whether location permission is permanently denied (user must open settings).
  static Future<bool> isLocationPermanentlyDenied() async {
    final status = await Permission.location.status;
    return status.isPermanentlyDenied;
  }

  /// Get current location with accuracy (legacy; for full punch payload use getLivePosition).
  static Future<Position> getCurrentLocation() async {
    final isGranted = await isLocationPermissionGranted();
    if (!isGranted) {
      throw Exception('Location permission not granted');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open app settings for location permission / GPS
  static Future<void> openLocationSettings() async {
    await openAppSettings();
  }

  /// Open system location/GPS settings (turn on GPS)
  static Future<bool> openSystemLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Get last known position (cached)
  static Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Fetches live GPS for punch-in/out: checks service, permission, high-accuracy fix,
  /// optional stream improvement, mock detection, optional reverse geocode.
  /// Throws [LocationServiceException] with reason for UI to show dialog/CTA.
  static Future<LiveLocationResult> getLivePosition({
    bool requireGoodAccuracy = false,
    double accuracyThresholdMeters = kLocationAccuracyWarningThresholdMeters,
    bool tryStreamImprovement = true,
    bool reverseGeocode = true,
  }) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationServiceException(LocationFailureReason.serviceDisabled);
    }

    PermissionStatus status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        throw LocationServiceException(
          status.isPermanentlyDenied
              ? LocationFailureReason.permissionPermanentlyDenied
              : LocationFailureReason.permissionDenied,
        );
      }
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const LocationServiceException(LocationFailureReason.timeout);
    } catch (e) {
      throw LocationServiceException(LocationFailureReason.other, e.toString());
    }

    if (tryStreamImprovement) {
      try {
        final better = await _improveWithStream(position, const Duration(seconds: 4));
        if (better != null) position = better;
      } catch (_) {
        // Keep initial position
      }
    }

    // Caller decides whether to block or mark suspicious when position.isMocked is true.

    if (requireGoodAccuracy && position.accuracy > accuracyThresholdMeters) {
      throw const LocationServiceException(LocationFailureReason.accuracyPoor);
    }

    String? address;
    if (reverseGeocode) {
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          address = _formatShortAddress(placemarks.first);
        }
      } catch (_) {
        // Optional: leave address null
      }
    }

    return LiveLocationResult(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isMocked: position.isMocked,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
      address: address?.trim().isEmpty == true ? null : address,
    );
  }

  /// Optional: run position stream with bestForNavigation for a short time and return better position if any.
  static Future<Position?> _improveWithStream(Position initial, Duration duration) async {
    Position best = initial;
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    final end = DateTime.now().add(duration);
    await for (final p in stream) {
      if (DateTime.now().isAfter(end)) break;
      if (p.accuracy < best.accuracy) best = p;
    }
    return best == initial ? null : best;
  }

  static String _formatShortAddress(Placemark p) {
    final parts = <String>[
      if (p.street != null && p.street!.isNotEmpty) p.street!,
      if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
      if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
      if (p.country != null && p.country!.isNotEmpty) p.country!,
    ];
    return parts.join(', ');
  }
}