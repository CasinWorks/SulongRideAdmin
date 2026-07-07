enum AppMaintenancePhase { inactive, scheduled, active }

class AppMaintenanceStatus {
  const AppMaintenanceStatus({
    required this.phase,
    this.id,
    this.title,
    this.message,
    this.startsAt,
    this.endsAt,
    this.blockApps = false,
    this.notifyUsers = false,
  });

  final AppMaintenancePhase phase;
  final String? id;
  final String? title;
  final String? message;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool blockApps;
  final bool notifyUsers;

  bool get isBlocking => phase == AppMaintenancePhase.active && blockApps;

  bool get shouldNotify =>
      notifyUsers &&
      (phase == AppMaintenancePhase.scheduled || phase == AppMaintenancePhase.active);

  factory AppMaintenanceStatus.inactive() {
    return const AppMaintenanceStatus(phase: AppMaintenancePhase.inactive);
  }

  factory AppMaintenanceStatus.fromJson(Map<String, dynamic> json) {
    final phaseRaw = json['phase'] as String? ?? 'inactive';
    final phase = switch (phaseRaw) {
      'active' => AppMaintenancePhase.active,
      'scheduled' => AppMaintenancePhase.scheduled,
      _ => AppMaintenancePhase.inactive,
    };
    if (phase == AppMaintenancePhase.inactive) {
      return AppMaintenanceStatus.inactive();
    }
    return AppMaintenanceStatus(
      phase: phase,
      id: json['id']?.toString(),
      title: json['title'] as String?,
      message: json['message'] as String?,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())?.toLocal()
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())?.toLocal()
          : null,
      blockApps: json['block_apps'] as bool? ?? true,
      notifyUsers: json['notify_users'] as bool? ?? true,
    );
  }
}
