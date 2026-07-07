import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_model.dart';

class DriverRepository {
  DriverRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> driversStream() {
    return _client.from('drivers').stream(primaryKey: ['id']);
  }

  Future<DriverModel?> fetchDriver(String id) async {
    try {
      final row =
          await _client.from('drivers').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return DriverModel.fromJson(row);
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> driverStream(String id) {
    return _client.from('drivers').stream(primaryKey: ['id']).eq('id', id);
  }
}
