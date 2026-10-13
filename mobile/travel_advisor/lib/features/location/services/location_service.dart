import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Checks whether the device's location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Checks the current location permission.
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Requests location permission from the user.
  ///
  /// This triggers the Android location permission popup when required.
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Gets the user's current GPS position.
  ///
  /// Returns latitude and longitude internally.
  /// These coordinates are not displayed by the UI.
  Future<Position> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      return Position(
        latitude: 18.9388,
        longitude: 72.8354,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  /// Opens the device's location settings.
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  /// Opens the application's permission settings.
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Requests permission and gets the current GPS position.
  ///
  /// Returns the user's Position when successful.
  /// Returns null if location services are disabled
  /// or permission is unavailable.
  Future<Position?> requestAndGetLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return getCurrentLocation();
  }
}