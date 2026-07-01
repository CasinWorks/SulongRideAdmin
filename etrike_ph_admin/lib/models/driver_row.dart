class DriverRow {
  const DriverRow({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.trikePlateNumber,
    this.trikeModel,
    required this.approvalStatus,
    required this.createdAt,
    this.isOnline = false,
    this.isAvailable = false,
    this.employmentType = 'contractual',
    this.station = 'Carmona Central',
    this.shiftSchedule = 'Mon–Sat · 6:00 AM – 2:00 PM',
    this.emergencyContact = '',
    this.startDate,
    this.shiftDays = const [1, 2, 3, 4, 5, 6],
    this.shiftStart = '06:00:00',
    this.shiftEnd = '14:00:00',
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? trikePlateNumber;
  final String? trikeModel;
  final String approvalStatus;
  final DateTime? createdAt;
  final bool isOnline;
  final bool isAvailable;
  final String employmentType;
  final String station;
  final String shiftSchedule;
  final String emergencyContact;
  final DateTime? startDate;
  final List<int> shiftDays;
  final String shiftStart;
  final String shiftEnd;

  String get employmentLabel =>
      employmentType == 'permanent' ? 'Permanent' : 'Contractual';

  factory DriverRow.fromJson(Map<String, dynamic> json) {
    return DriverRow(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      trikePlateNumber: json['trike_plate_number'] as String?,
      trikeModel: json['trike_model'] as String?,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      employmentType: json['employment_type'] as String? ?? 'contractual',
      station: json['station'] as String? ?? 'Carmona Central',
      shiftSchedule: json['shift_schedule'] as String? ?? 'Mon–Sat · 6:00 AM – 2:00 PM',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      shiftDays: _parseDays(json['shift_days']),
      shiftStart: json['shift_start'] as String? ?? '06:00:00',
      shiftEnd: json['shift_end'] as String? ?? '14:00:00',
    );
  }

  static List<int> _parseDays(Object? raw) {
    if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
    return const [1, 2, 3, 4, 5, 6];
  }
}
