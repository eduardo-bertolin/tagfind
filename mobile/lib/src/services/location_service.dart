import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps the Geolocator package with permission handling and fallback.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Get the current GPS coordinates.
  /// Falls back to default position if GPS hardware is unavailable (e.g. desktop).
  Future<Position?> getCurrentPosition() async {
    try {
      if (!Platform.isWindows) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) return null;
      } else {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Native GPS unavailable: $e');
    }

    // Fallback coordinates for desktop/simulated testing (Cascavel, PR)
    return Position(
      latitude: -24.9558,
      longitude: -53.4552,
      timestamp: DateTime.now(),
      accuracy: 15,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}
