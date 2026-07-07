import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_maintenance.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._client);

  final SupabaseClient _client;

  Future<AppMaintenanceStatus> fetchStatus() async {
    try {
      final raw = await _client.rpc('get_app_maintenance_status');
      if (raw is Map) {
        return AppMaintenanceStatus.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is Map<String, dynamic>) {
        return AppMaintenanceStatus.fromJson(raw);
      }
    } catch (_) {}
    return AppMaintenanceStatus.inactive();
  }
}
