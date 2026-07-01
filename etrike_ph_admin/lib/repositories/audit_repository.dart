import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_log_row.dart';

class AuditRepository {
  AuditRepository(
    this._client, {
    this.appSource = 'admin',
    this.actorRole = 'operator',
  });

  final SupabaseClient _client;
  final String appSource;
  final String actorRole;

  Future<void> log({
    required String action,
    required String summary,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String? actorName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('audit_logs').insert({
        'actor_id': user.id,
        'actor_role': actorRole,
        'actor_email': user.email,
        if (actorName != null) 'actor_name': actorName,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'summary': summary,
        'metadata': metadata ?? <String, dynamic>{},
        'app_source': appSource,
      });
    } catch (_) {
      // Never block the primary action if audit insert fails.
    }
  }

  Future<List<AuditLogRow>> fetchLogs({int limit = 100, String? actionFilter}) async {
    try {
      var query = _client.from('audit_logs').select();
      if (actionFilter != null && actionFilter.isNotEmpty) {
        query = query.eq('action', actionFilter);
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return (rows as List<dynamic>)
          .map((e) => AuditLogRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AuditLogRow>> fetchLogsForDriver(String driverId, {int limit = 25}) async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select()
          .or('and(entity_type.eq.drivers,entity_id.eq.$driverId),actor_id.eq.$driverId')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>)
          .map((e) => AuditLogRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
