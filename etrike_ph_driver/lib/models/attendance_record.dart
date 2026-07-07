class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.driverId,
    required this.clockIn,
    this.clockOut,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String driverId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String? notes;
  final DateTime createdAt;

  bool get isOpen => clockOut == null;

  Duration get duration {
    final end = clockOut ?? DateTime.now();
    return end.difference(clockIn);
  }

  static AttendanceRecord? tryFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final driverId = json['driver_id']?.toString();
    final clockInRaw = json['clock_in']?.toString();
    if (id == null || driverId == null || clockInRaw == null) return null;

    final clockIn = DateTime.tryParse(clockInRaw);
    if (clockIn == null) return null;

    final createdRaw = json['created_at']?.toString();
    final createdAt = createdRaw != null
        ? DateTime.tryParse(createdRaw) ?? clockIn
        : clockIn;

    return AttendanceRecord(
      id: id,
      driverId: driverId,
      clockIn: clockIn,
      clockOut: json['clock_out'] != null
          ? DateTime.tryParse(json['clock_out'].toString())
          : null,
      notes: json['notes']?.toString(),
      createdAt: createdAt,
    );
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final record = tryFromJson(json);
    if (record == null) {
      throw FormatException('Invalid attendance row: $json');
    }
    return record;
  }
}
