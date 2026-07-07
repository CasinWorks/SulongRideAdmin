import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLngBounds boundsForPoints(List<LatLng> points) {
  if (points.isEmpty) {
    return LatLngBounds(
      southwest: const LatLng(0, 0),
      northeast: const LatLng(0, 0),
    );
  }

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  if ((maxLat - minLat).abs() < 0.002) {
    minLat -= 0.002;
    maxLat += 0.002;
  }
  if ((maxLng - minLng).abs() < 0.002) {
    minLng -= 0.002;
    maxLng += 0.002;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

String cameraKeyForPoints(List<LatLng> points) {
  return points
      .map((p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}')
      .join('|');
}
