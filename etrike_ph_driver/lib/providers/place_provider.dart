import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_model.dart';
import '../repositories/place_repository.dart';
import 'auth_provider.dart';

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepository(ref.watch(supabaseClientProvider)),
);

final activePlacesProvider = FutureProvider<List<PlaceModel>>((ref) {
  return ref.watch(placeRepositoryProvider).listActivePlaces();
});
