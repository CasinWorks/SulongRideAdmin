import 'package:supabase_flutter/supabase_flutter.dart';

import 'audit_repository.dart';

class LocationRepository {
  LocationRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _client.from('drivers').update({
        'current_lat': lat,
        'current_lng': lng,
      }).eq('id', driverId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setDriverOnline({
    required String driverId,
    required bool isOnline,
  }) async {
    try {
      await _client.from('drivers').update({
        'is_online': isOnline,
        'is_available': isOnline,
      }).eq('id', driverId);
      await _audit.log(
        action: isOnline ? 'driver.go_online' : 'driver.go_offline',
        entityType: 'drivers',
        entityId: driverId,
        summary: isOnline ? 'Driver went online' : 'Driver went offline',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> fetchDriverOnline(String driverId) async {
    try {
      final row = await _client
          .from('drivers')
          .select('is_online')
          .eq('id', driverId)
          .maybeSingle();
      return row?['is_online'] as bool? ?? false;
    } catch (e) {
      rethrow;
    }
  }
}
