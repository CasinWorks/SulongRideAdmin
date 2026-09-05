import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/geo.dart';

class PlaceModel {
  const PlaceModel({
    required this.id,
    required this.slug,
    required this.name,
    this.displayName,
    this.notes,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    this.isActive = true,
  });

  /// First live village. Used until Supabase `places` loads.
  static const fallbackMalagasang = PlaceModel(
    id: 'local-malagasang-1-b',
    slug: 'malagasang-1-b',
    name: 'Malagasang 1-B',
    displayName: 'Malagasang 1-B, Imus, Cavite',
    notes: 'First Sulong Ride service village.',
    centerLat: 14.3922,
    centerLng: 120.9286,
    radiusKm: 1.8,
  );

  final String id;
  final String slug;
  final String name;
  final String? displayName;
  final String? notes;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final bool isActive;

  String get label => (displayName?.trim().isNotEmpty == true) ? displayName!.trim() : name;

  bool get isPersisted => !id.startsWith('local-');

  LatLng get center => LatLng(centerLat, centerLng);

  bool contains(LatLng point) =>
      haversineKm(centerLat, centerLng, point.latitude, point.longitude) <= radiusKm;

  int get searchRadiusMeters =>
      (radiusKm * 1000).round().clamp(800, 8000);

  double get recommendedZoom {
    if (radiusKm <= 1.2) return 16;
    if (radiusKm <= 2.5) return 15;
    if (radiusKm <= 5) return 14;
    return 13;
  }

  double get minZoom {
    if (radiusKm <= 2.5) return 14;
    if (radiusKm <= 5) return 13;
    return 12;
  }

  /// Tight box so the map stays on this village, with a little pan room.
  LatLngBounds get cameraBounds {
    final padKm = radiusKm * 1.8;
    final dLat = padKm / 111.32;
    final dLng = padKm / (111.32 * cos(centerLat * pi / 180));
    return LatLngBounds(
      southwest: LatLng(centerLat - dLat, centerLng - dLng),
      northeast: LatLng(centerLat + dLat, centerLng + dLng),
    );
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String?,
      notes: json['notes'] as String?,
      centerLat: (json['center_lat'] as num?)?.toDouble() ?? 0,
      centerLng: (json['center_lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 5,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
