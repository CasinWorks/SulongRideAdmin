import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Driver row from `drivers`.
// TODO: VERIFY DATA SHAPE — confirm columns match Supabase `drivers`.
class DriverModel {
  const DriverModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
    this.trikePlateNumber,
    this.trikeModel,
    this.isAvailable = false,
    this.isOnline = false,
    this.approvalStatus = 'pending',
    this.currentLat,
    this.currentLng,
    this.station = 'Malagasang 1-B',
    this.shiftSchedule = 'Mon–Sat · 6:00 AM – 2:00 PM',
    this.employmentType = 'contractual',
    this.shiftDays = const [1, 2, 3, 4, 5, 6],
    this.shiftStart = '06:00:00',
    this.shiftEnd = '14:00:00',
    this.placeId,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;
  final String? trikePlateNumber;
  final String? trikeModel;
  final bool isAvailable;
  final bool isOnline;
  final String approvalStatus;
  final double? currentLat;
  final double? currentLng;
  final String station;
  final String shiftSchedule;
  final String employmentType;
  final List<int> shiftDays;
  final String shiftStart;
  final String shiftEnd;
  final String? placeId;

  bool get isApproved => approvalStatus == 'approved';

  String get employmentLabel =>
      employmentType == 'permanent' ? 'Permanent' : 'Contractual';

  bool get worksToday => isOnShiftDay();

  bool isOnShiftDay([DateTime? now]) {
    final day = (now ?? DateTime.now()).weekday;
    return shiftDays.contains(day);
  }

  /// True when [now] is inside the scheduled window, including overnight shifts.
  bool canStartShift([DateTime? now]) {
    final n = now ?? DateTime.now();
    final start = _minutesOfDay(shiftStart);
    final end = _minutesOfDay(shiftEnd);
    if (start == null || end == null || start == end) {
      return isOnShiftDay(n);
    }
    final current = n.hour * 60 + n.minute;
    if (start < end) {
      return isOnShiftDay(n) && current >= start && current < end;
    }
    if (current >= start) return isOnShiftDay(n);
    return isOnShiftDay(n.subtract(const Duration(days: 1)));
  }

  String get shiftWindowLabel {
    final days = _shiftDaysLabel;
    return '$days · ${_formatClock(shiftStart)} – ${_formatClock(shiftEnd)}';
  }

  String get _shiftDaysLabel {
    if (shiftDays.length >= 7) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...shiftDays]..sort();
    return sorted
        .where((d) => d >= 1 && d <= 7)
        .map((d) => names[d - 1])
        .join(', ');
  }

  static int? _minutesOfDay(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h % 24) * 60 + (m % 60);
  }

  static String _formatClock(String raw) {
    final mins = _minutesOfDay(raw);
    if (mins == null) return raw;
    final h = mins ~/ 60;
    final m = mins % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  LatLng? get latLng {
    if (currentLat == null || currentLng == null) return null;
    return LatLng(currentLat!, currentLng!);
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      trikePlateNumber: json['trike_plate_number'] as String?,
      trikeModel: json['trike_model'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      station: json['station'] as String? ?? 'Malagasang 1-B',
      shiftSchedule: json['shift_schedule'] as String? ?? 'Mon–Sat · 6:00 AM – 2:00 PM',
      employmentType: json['employment_type'] as String? ?? 'contractual',
      shiftDays: _parseDays(json['shift_days']),
      shiftStart: json['shift_start'] as String? ?? '06:00:00',
      shiftEnd: json['shift_end'] as String? ?? '14:00:00',
      placeId: json['place_id'] as String?,
    );
  }

  static List<int> _parseDays(Object? raw) {
    if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
    return const [1, 2, 3, 4, 5, 6];
  }
}
