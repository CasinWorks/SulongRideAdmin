import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/audit_log_row.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_ui.dart';

class AuditLogsTab extends ConsumerWidget {
  const AuditLogsTab({super.key});

  static const _appLabels = {
    'admin': 'Admin',
    'driver': 'Driver app',
    'rider': 'Rider app',
  };

  static const _roleLabels = {
    'operator': 'Operator',
    'driver': 'Driver',
    'rider': 'Rider',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);
    final fmt = DateFormat('MMM d, yyyy · h:mm a');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Audit logs',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(auditLogsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'All account and fleet actions across admin, driver, and rider apps. Navigation is not logged.',
          style: TextStyle(fontSize: 13, color: AdminTokens.textSecondary),
        ),
        const SizedBox(height: 20),
        logsAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => AdminPanelCard(
            title: 'Could not load logs',
            child: Text('$e'),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return const AdminPanelCard(
                title: 'No entries yet',
                child: Text(
                  'Run fix_audit_logs.sql in Supabase, then perform actions in any app to see entries here.',
                ),
              );
            }
            return AdminPanelCard(
              title: 'Recent activity (${logs.length})',
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _AuditLogTile(log: logs[i], fmt: fmt),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.log, required this.fmt});

  final AuditLogRow log;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final appLabel = AuditLogsTab._appLabels[log.appSource] ?? log.appSource;
    final roleLabel = AuditLogsTab._roleLabels[log.actorRole] ?? log.actorRole;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminTokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForAction(log.action), size: 18, color: AdminTokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${log.actorLabel} · $roleLabel · $appLabel',
                  style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                ),
                if (log.entityType != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${log.entityType}${log.entityId != null ? ' · ${log.entityId}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmt.format(log.createdAt),
            style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    if (action.startsWith('trip.')) return Icons.local_taxi_outlined;
    if (action.startsWith('driver.')) return Icons.badge_outlined;
    if (action.startsWith('fare.')) return Icons.payments_outlined;
    if (action.startsWith('leave.')) return Icons.beach_access_outlined;
    if (action.startsWith('auth.')) return Icons.login_outlined;
    if (action.startsWith('chat.')) return Icons.chat_outlined;
    if (action.startsWith('attendance.')) return Icons.schedule_outlined;
    return Icons.history;
  }
}
