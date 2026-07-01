import 'driver_row.dart';

enum DriverDayStatus {
  onLeaveVl,
  onLeaveSl,
  onShift,
  online,
  offDuty,
  pending,
  revoked,
}

class DriverRosterEntry {
  const DriverRosterEntry({
    required this.driverId,
    required this.fullName,
    required this.email,
    required this.station,
    required this.shiftSchedule,
    required this.employmentType,
    required this.status,
    this.isOnline = false,
    this.isOnShift = false,
    this.leaveType,
    this.clockIn,
    this.clockOut,
    this.phone,
    this.plate,
    this.overallRating,
    this.totalReviews = 0,
  });

  final String driverId;
  final String fullName;
  final String email;
  final String station;
  final String shiftSchedule;
  final String employmentType;
  final DriverDayStatus status;
  final bool isOnline;
  final bool isOnShift;
  final String? leaveType;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? phone;
  final String? plate;
  final double? overallRating;
  final int totalReviews;

  String get statusLabel => switch (status) {
        DriverDayStatus.onLeaveVl => 'On leave (VL)',
        DriverDayStatus.onLeaveSl => 'On leave (SL)',
        DriverDayStatus.onShift => 'On shift',
        DriverDayStatus.online => 'Online',
        DriverDayStatus.offDuty => 'Off duty',
        DriverDayStatus.pending => 'Pending approval',
        DriverDayStatus.revoked => 'Revoked',
      };
}

class DayRosterSummary {
  const DayRosterSummary({
    required this.date,
    required this.entries,
  });

  final DateTime date;
  final List<DriverRosterEntry> entries;

  int get onShiftCount =>
      entries.where((e) => e.status == DriverDayStatus.onShift).length;
  int get onlineCount => entries.where((e) => e.isOnline).length;
  int get onLeaveCount => entries
      .where((e) =>
          e.status == DriverDayStatus.onLeaveVl ||
          e.status == DriverDayStatus.onLeaveSl)
      .length;
  int get offDutyCount =>
      entries.where((e) => e.status == DriverDayStatus.offDuty).length;
}

class AttendanceBlock {
  const AttendanceBlock({required this.clockIn, this.clockOut});

  final DateTime clockIn;
  final DateTime? clockOut;
}

class DriverScheduleDay {
  const DriverScheduleDay({
    required this.date,
    required this.status,
    this.leaveType,
    this.attendanceBlocks = const [],
  });

  final DateTime date;
  final DriverDayStatus status;
  final String? leaveType;
  final List<AttendanceBlock> attendanceBlocks;
}

class DriverDirectoryEntry {
  const DriverDirectoryEntry({
    required this.driver,
    required this.todayStatus,
    required this.isOnline,
    required this.isOnShift,
    this.leaveTypeToday,
    this.overallRating,
    this.totalReviews = 0,
  });

  final DriverRow driver;
  final DriverDayStatus todayStatus;
  final bool isOnline;
  final bool isOnShift;
  final String? leaveTypeToday;
  final double? overallRating;
  final int totalReviews;
}
