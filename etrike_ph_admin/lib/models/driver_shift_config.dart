import 'package:flutter/material.dart';

/// ISO weekday: 1 = Mon … 7 = Sun
class DriverShiftConfig {
  const DriverShiftConfig({
    required this.days,
    required this.start,
    required this.end,
    this.station = 'Carmona Central',
    this.employmentType = 'contractual',
  });

  final Set<int> days;
  final TimeOfDay start;
  final TimeOfDay end;
  final String station;
  final String employmentType;

  static const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const presetStations = [
    'Carmona Central',
    'Vista Mall Carmona',
    'Southwoods Hub',
    'Carmona Public Market',
  ];

  static const presets = <String, DriverShiftConfig>{
    'Morning (6 AM – 2 PM)': DriverShiftConfig(
      days: {1, 2, 3, 4, 5, 6},
      start: TimeOfDay(hour: 6, minute: 0),
      end: TimeOfDay(hour: 14, minute: 0),
    ),
    'Afternoon (2 PM – 10 PM)': DriverShiftConfig(
      days: {1, 2, 3, 4, 5, 6},
      start: TimeOfDay(hour: 14, minute: 0),
      end: TimeOfDay(hour: 22, minute: 0),
    ),
    'Mon–Fri day': DriverShiftConfig(
      days: {1, 2, 3, 4, 5},
      start: TimeOfDay(hour: 6, minute: 0),
      end: TimeOfDay(hour: 14, minute: 0),
    ),
  };

  factory DriverShiftConfig.fromJson(Map<String, dynamic> json) {
    final rawDays = json['shift_days'];
    Set<int> days = {1, 2, 3, 4, 5, 6};
    if (rawDays is List) {
      days = rawDays.map((e) => (e as num).toInt()).toSet();
    }

    return DriverShiftConfig(
      days: days,
      start: _parseTime(json['shift_start'] as String? ?? '06:00:00'),
      end: _parseTime(json['shift_end'] as String? ?? '14:00:00'),
      station: json['station'] as String? ?? 'Carmona Central',
      employmentType: json['employment_type'] as String? ?? 'contractual',
    );
  }

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    final h = int.tryParse(parts.first) ?? 6;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String get employmentLabel =>
      employmentType == 'permanent' ? 'Permanent' : 'Contractual';

  String toDisplayString() {
    final sorted = days.toList()..sort();
    final dayPart = _formatDayRange(sorted);
    return '$dayPart · ${_formatTime(start)} – ${_formatTime(end)}';
  }

  String _formatDayRange(List<int> sorted) {
    if (sorted.isEmpty) return 'No days';
    if (sorted.length == 7) return 'Mon–Sun';
    if (sorted.length == 6 && !sorted.contains(7)) return 'Mon–Sat';
    if (sorted.length == 5 && sorted.every((d) => d <= 5)) return 'Mon–Fri';
    return sorted.map((d) => weekdayLabels[d - 1]).join(', ');
  }

  String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _formatTime(TimeOfDay t) => formatTime(t);

  String _timeToPg(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Map<String, dynamic> toUpdatePayload() {
    final sortedDays = days.toList()..sort();
    return {
      'shift_days': sortedDays,
      'shift_start': _timeToPg(start),
      'shift_end': _timeToPg(end),
      'shift_schedule': toDisplayString(),
      'station': station,
      'employment_type': employmentType,
    };
  }

  bool worksOn(DateTime date) => days.contains(date.weekday);

  DriverShiftConfig copyWith({
    Set<int>? days,
    TimeOfDay? start,
    TimeOfDay? end,
    String? station,
    String? employmentType,
  }) {
    return DriverShiftConfig(
      days: days ?? this.days,
      start: start ?? this.start,
      end: end ?? this.end,
      station: station ?? this.station,
      employmentType: employmentType ?? this.employmentType,
    );
  }
}
