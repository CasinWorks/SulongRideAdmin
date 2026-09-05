import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Default map center — Malagasang 1-B, Imus, Cavite.
abstract final class MapRegions {
  static const LatLng malagasang1bCenter = LatLng(14.3922, 120.9286);
  static const LatLng defaultServiceCenter = malagasang1bCenter;

  /// Kept for older call sites.
  static const LatLng carmonaCenter = malagasang1bCenter;

  static const int searchRadiusMeters = 2500;
}
