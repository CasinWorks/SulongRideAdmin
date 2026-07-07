/// Formats Google Directions duration for UI labels.
String formatEtaMinutes(int? durationSeconds, {String fallback = '—'}) {
  if (durationSeconds == null || durationSeconds <= 0) return fallback;
  final mins = (durationSeconds / 60).ceil().clamp(1, 999);
  return '~$mins min';
}

/// Formats driving route distance for booking chips.
String formatRouteDistanceKm(double distanceKm) {
  if (distanceKm <= 0) return '—';
  if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
  if (distanceKm < 10) return '${distanceKm.toStringAsFixed(1)} km';
  return '${distanceKm.round()} km';
}

/// Fallback when Directions is unavailable (~25 km/h urban average).
int estimateDurationSecondsFromKm(double? distanceKm) {
  if (distanceKm == null || distanceKm <= 0) return 0;
  return (distanceKm / 25 * 3600).ceil();
}
