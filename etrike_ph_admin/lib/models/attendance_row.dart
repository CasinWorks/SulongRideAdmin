class AttendanceRow {
  const AttendanceRow({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverEmail,
    required this.clockIn,
    this.clockOut,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String driverEmail;
  final DateTime clockIn;
  final DateTime? clockOut;

  bool get isOpen => clockOut == null;

  factory AttendanceRow.fromJson(Map<String, dynamic> json) {
    final driver = json['drivers'] as Map<String, dynamic>?;
    return AttendanceRow(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      driverName: driver?['full_name'] as String? ?? 'Driver',
      driverEmail: driver?['email'] as String? ?? '',
      clockIn: DateTime.parse(json['clock_in'] as String),
      clockOut: json['clock_out'] != null
          ? DateTime.tryParse(json['clock_out'] as String)
          : null,
    );
  }
}
