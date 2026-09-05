import 'package:supabase_flutter/supabase_flutter.dart';

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
}
