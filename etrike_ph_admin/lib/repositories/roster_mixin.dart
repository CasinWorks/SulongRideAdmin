import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_row.dart';
import '../models/driver_row.dart';
import '../models/driver_row_shift.dart';
import '../models/leave_row.dart';
import '../models/roster_models.dart';
import '../utils/rating_analytics.dart';

/// Roster & schedule queries for [AdminRepository].
mixin AdminRosterMixin {
  SupabaseClient get rosterClient;
  Future<List<DriverRow>> listDrivers({String? approvalStatus});

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _dateInRange(DateTime day, DateTime start, DateTime end) {
    final d = _dayOnly(day);
    return !d.isBefore(_dayOnly(start)) && !d.isAfter(_dayOnly(end));
  }

  bool _wasOnShift(AttendanceRow a, DateTime day) {
    final d = _dayOnly(day);
    final inD = _dayOnly(a.clockIn.toLocal());
    if (inD.isAfter(d)) return false;
    if (a.clockOut == null) return !inD.isAfter(d);
    final outD = _dayOnly(a.clockOut!.toLocal());
    return !outD.isBefore(d);
  }

  Future<Map<String, ({double? rating, int reviews})>> _fetchDriverRatings() async {
    try {
      final rows = await rosterClient
          .from('trips')
          .select('id, driver_id, rating')
          .eq('status', 'completed');
      final byDriver = <String, List<double>>{};
      final tripToDriver = <String, String>{};
      final ratedTripIds = <String>{};
      for (final row in rows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final driverId = map['driver_id'] as String?;
        final tripId = map['id'] as String?;
        final rating = (map['rating'] as num?)?.toDouble();
        if (tripId != null && driverId != null) {
          tripToDriver[tripId] = driverId;
        }
        if (driverId == null || rating == null) continue;
        ratedTripIds.add(tripId ?? '');
        byDriver.putIfAbsent(driverId, () => []).add(rating);
      }

      try {
        final auditRows = await rosterClient
            .from('audit_logs')
            .select('entity_id, metadata')
            .eq('action', 'trip.rate')
            .eq('entity_type', 'trips')
            .order('created_at', ascending: false);
        for (final raw in auditRows as List<dynamic>) {
          final row = raw as Map<String, dynamic>;
          final tripId = row['entity_id'] as String?;
          if (tripId == null || ratedTripIds.contains(tripId)) continue;
          final meta = row['metadata'];
          if (meta is! Map) continue;
          final rating = (meta['rating'] as num?)?.toDouble();
          final driverId = tripToDriver[tripId];
          if (rating == null || driverId == null) continue;
          ratedTripIds.add(tripId);
          byDriver.putIfAbsent(driverId, () => []).add(rating);
        }
      } catch (_) {}

      return byDriver.map(
        (id, ratings) => MapEntry(
          id,
          (
            rating: RatingAnalytics.averageRating(ratings),
            reviews: ratings.length,
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<List<AttendanceRow>> _fetchAllAttendance() async {
    try {
      final rows = await rosterClient
          .from('driver_attendance')
          .select('*, drivers(full_name, email)')
          .order('clock_in', ascending: false)
          .limit(500);
      return (rows as List<dynamic>)
          .map((e) => AttendanceRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<LeaveRow>> _fetchApprovedLeave() async {
    try {
      final rows = await rosterClient
          .from('leave_requests')
          .select('*, drivers(full_name, email)')
          .eq('status', 'approved');
      return (rows as List<dynamic>)
          .map((e) => LeaveRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DayRosterSummary> fetchRosterForDate(DateTime day) async {
    final drivers = await listDrivers();
    final attendance = await _fetchAllAttendance();
    final leaves = await _fetchApprovedLeave();
    final ratings = await _fetchDriverRatings();
    final d = _dayOnly(day);
    final isToday = d == _dayOnly(DateTime.now());

    final entries = <DriverRosterEntry>[];
    for (final driver in drivers) {
      final ratingInfo = ratings[driver.id];

      if (driver.approvalStatus != 'approved') {
        entries.add(DriverRosterEntry(
          driverId: driver.id,
          fullName: driver.fullName.isNotEmpty ? driver.fullName : driver.email,
          email: driver.email,
          station: driver.station,
          shiftSchedule: driver.shiftSchedule,
          employmentType: driver.employmentLabel,
          status: driver.approvalStatus == 'pending'
              ? DriverDayStatus.pending
              : DriverDayStatus.revoked,
          phone: driver.phone,
          plate: driver.trikePlateNumber,
          overallRating: ratingInfo?.rating,
          totalReviews: ratingInfo?.reviews ?? 0,
        ));
        continue;
      }

      LeaveRow? leaveToday;
      for (final l in leaves) {
        if (l.driverId == driver.id && _dateInRange(d, l.startDate, l.endDate)) {
          leaveToday = l;
          break;
        }
      }

      final dayAttendance =
          attendance.where((a) => a.driverId == driver.id && _wasOnShift(a, d)).toList();
      final onShift = leaveToday == null && dayAttendance.isNotEmpty;
      final openNow = isToday && dayAttendance.any((a) => a.isOpen);

      final scheduledDay = driver.shiftConfig.worksOn(d);

      DriverDayStatus status;
      if (leaveToday != null) {
        status = leaveToday.leaveType == 'SL'
            ? DriverDayStatus.onLeaveSl
            : DriverDayStatus.onLeaveVl;
      } else if (onShift) {
        status = DriverDayStatus.onShift;
      } else if (!scheduledDay) {
        status = DriverDayStatus.offDuty;
      } else if (isToday && driver.isOnline) {
        status = DriverDayStatus.online;
      } else {
        status = DriverDayStatus.offDuty;
      }

      AttendanceRow? primary;
      if (dayAttendance.isNotEmpty) primary = dayAttendance.first;

      entries.add(DriverRosterEntry(
        driverId: driver.id,
        fullName: driver.fullName.isNotEmpty ? driver.fullName : driver.email,
        email: driver.email,
        station: driver.station,
        shiftSchedule: scheduledDay
            ? driver.shiftSchedule
            : '${driver.shiftSchedule} (off today)',
        employmentType: driver.employmentLabel,
        status: status,
        isOnline: isToday && driver.isOnline,
        isOnShift: onShift && openNow,
        leaveType: leaveToday?.leaveType,
        clockIn: primary?.clockIn,
        clockOut: primary?.clockOut,
        phone: driver.phone,
        plate: driver.trikePlateNumber,
        overallRating: ratingInfo?.rating,
        totalReviews: ratingInfo?.reviews ?? 0,
      ));
    }

    entries.sort((a, b) {
      const order = {
        DriverDayStatus.onShift: 0,
        DriverDayStatus.online: 1,
        DriverDayStatus.offDuty: 2,
        DriverDayStatus.onLeaveVl: 3,
        DriverDayStatus.onLeaveSl: 4,
        DriverDayStatus.pending: 5,
        DriverDayStatus.revoked: 6,
      };
      final c = order[a.status]!.compareTo(order[b.status]!);
      if (c != 0) return c;
      return a.fullName.compareTo(b.fullName);
    });

    return DayRosterSummary(date: d, entries: entries);
  }

  Future<Map<DateTime, int>> fetchShiftCountsForMonth(DateTime month) async {
    final attendance = await _fetchAllAttendance();
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final counts = <DateTime, int>{};

    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final day = _dayOnly(d);
      final ids = attendance.where((a) => _wasOnShift(a, day)).map((a) => a.driverId).toSet();
      if (ids.isNotEmpty) counts[day] = ids.length;
    }
    return counts;
  }

  Future<List<DriverScheduleDay>> fetchDriverSchedule(
    String driverId,
    DateTime month,
  ) async {
    final attendance = await _fetchAllAttendance();
    final leaves = await _fetchApprovedLeave();
    final drivers = await listDrivers();
    final driver = drivers.cast<DriverRow?>().firstWhere(
          (d) => d?.id == driverId,
          orElse: () => null,
        );
    if (driver == null) return [];

    final shift = driver.shiftConfig;

    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final today = _dayOnly(DateTime.now());
    final days = <DriverScheduleDay>[];

    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final day = _dayOnly(d);
      final blocks = attendance
          .where((a) => a.driverId == driverId && _wasOnShift(a, day))
          .map((a) => AttendanceBlock(clockIn: a.clockIn, clockOut: a.clockOut))
          .toList();

      LeaveRow? leave;
      for (final l in leaves) {
        if (l.driverId == driverId && _dateInRange(day, l.startDate, l.endDate)) {
          leave = l;
          break;
        }
      }

      final DriverDayStatus status;
      if (leave != null) {
        status = leave.leaveType == 'SL'
            ? DriverDayStatus.onLeaveSl
            : DriverDayStatus.onLeaveVl;
      } else if (!shift.worksOn(day)) {
        status = DriverDayStatus.offDuty;
      } else if (blocks.isNotEmpty) {
        status = DriverDayStatus.onShift;
      } else if (day == today && driver.isOnline) {
        status = DriverDayStatus.online;
      } else {
        status = DriverDayStatus.offDuty;
      }

      days.add(DriverScheduleDay(
        date: day,
        status: status,
        leaveType: leave?.leaveType,
        attendanceBlocks: blocks,
      ));
    }
    return days;
  }

  Future<List<DriverDirectoryEntry>> fetchDriversDirectory() async {
    final drivers = await listDrivers();
    final roster = await fetchRosterForDate(DateTime.now());
    final byId = {for (final e in roster.entries) e.driverId: e};

    final list = drivers.map((d) {
      final r = byId[d.id];
      return DriverDirectoryEntry(
        driver: d,
        todayStatus: r?.status ??
            (d.approvalStatus == 'pending'
                ? DriverDayStatus.pending
                : d.approvalStatus == 'rejected'
                    ? DriverDayStatus.revoked
                    : DriverDayStatus.offDuty),
        isOnline: d.isOnline,
        isOnShift: r?.isOnShift ?? false,
        leaveTypeToday: r?.leaveType,
        overallRating: r?.overallRating,
        totalReviews: r?.totalReviews ?? 0,
      );
    }).toList();

    list.sort((a, b) {
      const order = {
        DriverDayStatus.onShift: 0,
        DriverDayStatus.online: 1,
        DriverDayStatus.offDuty: 2,
        DriverDayStatus.onLeaveVl: 3,
        DriverDayStatus.onLeaveSl: 4,
        DriverDayStatus.pending: 5,
        DriverDayStatus.revoked: 6,
      };
      final c = order[a.todayStatus]!.compareTo(order[b.todayStatus]!);
      if (c != 0) return c;
      return a.driver.fullName.compareTo(b.driver.fullName);
    });
    return list;
  }
}
