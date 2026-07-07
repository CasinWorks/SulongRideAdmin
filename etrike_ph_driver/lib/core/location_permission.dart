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
