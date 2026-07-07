import 'package:supabase_flutter/supabase_flutter.dart';

class AuditRepository {
  AuditRepository(
    this._client, {
    this.appSource = 'rider',
    this.actorRole = 'rider',
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
    } catch (_) {}
  }
}
