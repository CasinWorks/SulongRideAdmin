class LeaveRow {
  const LeaveRow({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory LeaveRow.fromJson(Map<String, dynamic> json) {
    final driver = json['drivers'] as Map<String, dynamic>?;
    return LeaveRow(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      driverName: driver?['full_name'] as String? ?? 'Driver',
      leaveType: json['leave_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
