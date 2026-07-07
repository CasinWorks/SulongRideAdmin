import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/training_models.dart';

class TrainingRepository {
  TrainingRepository(this._client);

  final SupabaseClient _client;

  String? get _driverId => _client.auth.currentUser?.id;

  Future<DriverTrainingRecord?> fetchTraining([String? driverId]) async {
    final id = driverId ?? _driverId;
    if (id == null) return null;
    try {
      final row = await _client
          .from('driver_training')
          .select()
          .eq('driver_id', id)
          .maybeSingle();
      if (row == null) return null;
      return DriverTrainingRecord.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<DriverTrainingRecord> ensureTrainingRow({TrainingMode mode = TrainingMode.online}) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    final existing = await fetchTraining(id);
    if (existing != null) return existing;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('driver_training').insert({
      'driver_id': id,
      'status': TrainingStatus.notStarted.dbValue,
      'mode': mode.dbValue,
      'created_at': now,
      'updated_at': now,
    });
    return (await fetchTraining(id))!;
  }

  Future<DriverTrainingRecord> markTrainingStarted() async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    await ensureTrainingRow();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('driver_training').update({
      'status': TrainingStatus.inProgress.dbValue,
      'started_at': now,
      'updated_at': now,
    }).eq('driver_id', id);
    return (await fetchTraining(id))!;
  }

  Future<DriverTrainingRecord> submitOnlineQuiz(Map<String, int> answers) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    final record = await ensureTrainingRow();
    if (record.mode == TrainingMode.onsite) {
      throw StateError(
        'Your operator scheduled onsite training. Complete the session in person — they will mark you complete in the admin portal.',
      );
    }
    final score = scoreTrainingQuiz(answers);
    if (score < kTrainingPassScore) {
      throw StateError('Score $score% — you need at least $kTrainingPassScore% to pass. Review the modules and try again.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('driver_training').update({
      'status': TrainingStatus.completed.dbValue,
      'mode': TrainingMode.online.dbValue,
      'quiz_score': score,
      'quiz_passed_at': now,
      'completed_at': now,
      'quiz_answers': answers.map((k, v) => MapEntry(k, v)),
      'updated_at': now,
    }).eq('driver_id', id);
    await _client.from('onboarding_timeline').insert({
      'driver_id': id,
      'action': 'training_completed',
      'summary': 'Completed online rider protocol training ($score%)',
    });
    return (await fetchTraining(id))!;
  }
}
