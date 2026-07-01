class AuditLogRow {
  const AuditLogRow({
    required this.id,
    required this.createdAt,
    required this.actorRole,
    required this.action,
    required this.summary,
    required this.appSource,
    this.actorId,
    this.actorEmail,
    this.actorName,
    this.entityType,
    this.entityId,
    this.metadata = const {},
  });

  final String id;
  final DateTime createdAt;
  final String? actorId;
  final String actorRole;
  final String? actorEmail;
  final String? actorName;
  final String action;
  final String? entityType;
  final String? entityId;
  final String summary;
  final String appSource;
  final Map<String, dynamic> metadata;

  String get actorLabel {
    if (actorName != null && actorName!.trim().isNotEmpty) return actorName!;
    if (actorEmail != null && actorEmail!.trim().isNotEmpty) return actorEmail!;
    return actorRole;
  }

  factory AuditLogRow.fromJson(Map<String, dynamic> json) {
    return AuditLogRow(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      actorId: json['actor_id'] as String?,
      actorRole: json['actor_role'] as String? ?? 'operator',
      actorEmail: json['actor_email'] as String?,
      actorName: json['actor_name'] as String?,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      summary: json['summary'] as String? ?? '',
      appSource: json['app_source'] as String? ?? 'admin',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }
}
