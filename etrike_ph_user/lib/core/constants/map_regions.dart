import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/place_model.dart';

/// Default map / search bias. Live service areas come from `places`.
abstract final class MapRegions {
  static const LatLng malagasang1bCenter = LatLng(14.3922, 120.9286);
  static const LatLng defaultServiceCenter = malagasang1bCenter;
  static const String defaultPlaceSlug = 'malagasang-1-b';

  /// Kept for older call sites; Carmona is no longer the default village.
  static const LatLng carmonaCenter = LatLng(14.3132, 121.0565);

  static const int searchRadiusMeters = 2500;

  static PlaceModel get defaultPlace => PlaceModel.fallbackMalagasang;
}
