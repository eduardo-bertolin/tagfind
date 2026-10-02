import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps the Geolocator package with permission handling.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Request location permissions and return `true` if granted.
  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Check whether location services are enabled and permissions granted.
  Future<bool> get isAvailable async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get the current GPS coordinates.
  /// Returns `null` if location is unavailable.
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await isAvailable) {
        final granted = await requestPermission();
        if (!granted) return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
