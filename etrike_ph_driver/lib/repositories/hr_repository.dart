import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_record.dart';
import '../models/driver_stats.dart';
import '../models/leave_request.dart';
import '../utils/trip_rating_enrichment.dart';
import 'audit_repository.dart';

class HrRepository {
  HrRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  String? get _driverId => _client.auth.currentUser?.id;

  Future<DriverStats> fetchDriverStats() async {
    final id = _driverId;
    if (id == null) {
      return const DriverStats(
        completedTrips: 0,
        totalEarnings: 0,
        attendanceDays: 0,
        openShift: false,
      );
    }

    final trips = await _client
        .from('trips')
        .select('id, fare, rating, complaint_tags, completed_at, created_at')
        .eq('driver_id', id)
        .eq('status', 'completed');

    final tripRows = trips as List<dynamic>;
    final audit = await fetchAuditRatingsByTripId(_client);
    var earnings = 0.0;
    final ratings = <double>[];
    var complaints7 = 0;
    final d7 = DateTime.now().subtract(const Duration(days: 7));
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final ratingsMonth = <double>[];

    for (final row in tripRows) {
      final map = row as Map<String, dynamic>;
      earnings += (map['fare'] as num?)?.toDouble() ?? 0;
      var rating = (map['rating'] as num?)?.toInt();
      if (rating == null) {
        final tripId = map['id'] as String?;
        if (tripId != null) rating = audit[tripId]?.rating;
      }
      if (rating != null) ratings.add(rating.toDouble());

      final completed = _parseOptionalDate(map['completed_at'] ?? map['created_at']);
      if (rating != null && completed != null && !completed.isBefore(monthStart)) {
        ratingsMonth.add(rating.toDouble());
      }
      if (completed != null && !completed.isBefore(d7)) {
        final tags = map['complaint_tags'];
        var tagCount = tags is List ? tags.length : 0;
        if (tagCount == 0) {
          final tripId = map['id'] as String?;
          if (tripId != null) tagCount = audit[tripId]?.tags.length ?? 0;
        }
        complaints7 += tagCount;
      }
    }

    double? avg(Iterable<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

    final attendance = await _client
        .from('driver_attendance')
        .select('id, driver_id, clock_in, clock_out, created_at')
        .eq('driver_id', id);

    final attRows = (attendance as List<dynamic>)
        .map((e) => AttendanceRecord.tryFromJson(e as Map<String, dynamic>))
        .whereType<AttendanceRecord>()
        .toList();

    final days = attRows
        .map((a) => DateTime(a.clockIn.year, a.clockIn.month, a.clockIn.day))
        .toSet()
        .length;

    final open = attRows.any((a) => a.isOpen);

    return DriverStats(
      completedTrips: tripRows.length,
      totalEarnings: earnings,
      attendanceDays: days,
      openShift: open,
      overallRating: avg(ratings),
      ratingThisMonth: avg(ratingsMonth) ?? avg(ratings),
      totalReviews: ratings.length,
      complaintsLast7d: complaints7,
    );
  }

  Future<AttendanceRecord?> fetchOpenAttendance() async {
    final id = _driverId;
    if (id == null) return null;
    try {
      final row = await _client
          .from('driver_attendance')
          .select()
          .eq('driver_id', id)
          .isFilter('clock_out', null)
          .order('clock_in', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return AttendanceRecord.tryFromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<AttendanceRecord>> fetchAttendanceHistory({int limit = 30}) async {
    final id = _driverId;
    if (id == null) return [];
    try {
      final rows = await _client
          .from('driver_attendance')
          .select()
          .eq('driver_id', id)
          .order('clock_in', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>)
          .map((e) => AttendanceRecord.tryFromJson(e as Map<String, dynamic>))
          .whereType<AttendanceRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clockIn() async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    final open = await fetchOpenAttendance();
    if (open != null) throw StateError('You are already timed in.');
    await _client.from('driver_attendance').insert({'driver_id': id});
    await _audit.log(
      action: 'attendance.clock_in',
      entityType: 'drivers',
      entityId: id,
      summary: 'Driver clocked in',
    );
  }

  Future<void> clockOut() async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    final open = await fetchOpenAttendance();
    if (open == null) throw StateError('No active time-in found.');
    await _client.from('driver_attendance').update({
      'clock_out': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', open.id);
    await _audit.log(
      action: 'attendance.clock_out',
      entityType: 'driver_attendance',
      entityId: open.id,
      summary: 'Driver clocked out',
    );
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final id = _driverId;
    if (id == null) return [];
    try {
      final rows = await _client
          .from('leave_requests')
          .select()
          .eq('driver_id', id)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> submitLeaveRequest({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');
    if (endDate.isBefore(startDate)) {
      throw StateError('End date must be on or after start date.');
    }
    await _client.from('leave_requests').insert({
      'driver_id': id,
      'leave_type': leaveType,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'reason': reason.trim(),
      'status': 'pending',
    });
    await _audit.log(
      action: 'leave.submit',
      entityType: 'drivers',
      entityId: id,
      summary: 'Leave request submitted ($leaveType)',
      metadata: {
        'leave_type': leaveType,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
      },
    );
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseOptionalDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}
