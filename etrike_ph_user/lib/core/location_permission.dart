import 'package:geolocator/geolocator.dart';

/// Requests location access via [Geolocator] (works on iOS, Android, macOS, etc.).
/// Avoid [permission_handler] on macOS — it has no native implementation there.
Future<LocationPermission> ensureLocationPermission() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.unableToDetermine) {
    permission = await Geolocator.requestPermission();
  }
  return permission;
}

Future<bool> hasUsableLocationPermission() async {
  final permission = await ensureLocationPermission();
  return permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}

Future<void> openLocationSettings() => Geolocator.openLocationSettings();

String locationPermissionHint(LocationPermission permission) {
  return switch (permission) {
    LocationPermission.deniedForever =>
      'Location was denied. Open System Settings → Privacy & Security → Location Services, enable Location Services, and allow Sulong Ride.',
    LocationPermission.denied =>
      'Location access was denied. Tap Retry to ask again, or enable location for Sulong Ride in System Settings.',
    LocationPermission.unableToDetermine =>
      'Could not determine location permission. Check System Settings → Privacy & Security → Location Services.',
    _ => 'Location permission is required to request rides.',
  };
}
