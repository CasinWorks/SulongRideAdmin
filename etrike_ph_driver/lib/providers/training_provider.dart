import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_models.dart';
import '../providers/auth_provider.dart';
import '../repositories/training_repository.dart';

final trainingRepositoryProvider = Provider<TrainingRepository>((ref) {
  return TrainingRepository(ref.watch(supabaseClientProvider));
});

final driverTrainingProvider = FutureProvider<DriverTrainingRecord?>((ref) async {
  ref.watch(authUserIdProvider);
  return ref.read(trainingRepositoryProvider).fetchTraining();
});
