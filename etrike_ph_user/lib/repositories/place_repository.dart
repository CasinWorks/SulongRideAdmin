import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/geo.dart';
import '../models/place_model.dart';

class PlaceRepository {
  PlaceRepository(this._client);

  final SupabaseClient _client;

  Future<List<PlaceModel>> listActivePlaces() async {
    try {
      final rows = await _client
          .from('places')
          .select()
          .eq('is_active', true)
          .order('name')
          .timeout(const Duration(seconds: 8));
      return (rows as List<dynamic>)
          .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<PlaceModel?> placeCovering(double lat, double lng) async {
    try {
      final id = await _client.rpc(
        'place_covering_point',
        params: {'p_lat': lat, 'p_lng': lng},
      );
      if (id is String) {
        final row = await _client.from('places').select().eq('id', id).maybeSingle();
        if (row != null) return PlaceModel.fromJson(row);
      }
    } catch (_) {}

    final places = await listActivePlaces();
    PlaceModel? best;
    var bestKm = double.infinity;
    for (final place in places) {
      final km = haversineKm(lat, lng, place.centerLat, place.centerLng);
      if (km <= place.radiusKm && km < bestKm) {
        best = place;
        bestKm = km;
      }
    }
    return best;
  }
}
