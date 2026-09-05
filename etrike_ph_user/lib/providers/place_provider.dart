import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/map_regions.dart';
import '../models/place_model.dart';
import '../repositories/place_repository.dart';
import 'auth_provider.dart';

const _selectedPlaceKey = 'selected_service_place_id';

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepository(ref.watch(supabaseClientProvider)),
);

final activePlacesProvider = FutureProvider<List<PlaceModel>>((ref) async {
  final places = await ref.watch(placeRepositoryProvider).listActivePlaces();
  if (places.isNotEmpty) return places;
  return const [PlaceModel.fallbackMalagasang];
});

class SelectedPlaceNotifier extends StateNotifier<PlaceModel> {
  SelectedPlaceNotifier(this._ref) : super(PlaceModel.fallbackMalagasang) {
    _hydrate();
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    List<PlaceModel> places = const [];
    try {
      places = await _ref.read(activePlacesProvider.future);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_selectedPlaceKey);
    state = _resolve(places, saved);
  }

  Future<void> select(PlaceModel place) async {
    state = place;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPlaceKey, place.isPersisted ? place.id : place.slug);
  }

  static PlaceModel _resolve(List<PlaceModel> places, String? saved) {
    if (saved != null) {
      for (final place in places) {
        if (place.id == saved || place.slug == saved) return place;
      }
    }
    for (final place in places) {
      if (place.slug == MapRegions.defaultPlaceSlug) return place;
    }
    if (places.isNotEmpty) return places.first;
    return PlaceModel.fallbackMalagasang;
  }
}

final selectedPlaceProvider =
    StateNotifierProvider<SelectedPlaceNotifier, PlaceModel>((ref) {
  return SelectedPlaceNotifier(ref);
});
