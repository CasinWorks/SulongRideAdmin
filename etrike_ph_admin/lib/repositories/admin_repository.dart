import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/admin_tokens.dart';
import '../models/admin_models.dart';
import '../models/attendance_row.dart';
import '../models/audit_log_row.dart';
import '../models/driver_row.dart';
import '../models/fare_config.dart';
import '../models/leave_row.dart';
import '../models/onboarding_models.dart';
import '../utils/rating_analytics.dart';
import 'audit_repository.dart';
import 'onboarding_repository.dart';
import 'roster_mixin.dart';

class AdminRepository with AdminRosterMixin {
  AdminRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  @override
  SupabaseClient get rosterClient => _client;

  Future<bool> isOperator() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row =
        await _client.from('operators').select('id').eq('id', uid).maybeSingle();
    return row != null;
  }

  @override
  Future<List<DriverRow>> listDrivers({String? approvalStatus}) async {
    var query = _client.from('drivers').select();
    if (approvalStatus != null) {
      query = query.eq('approval_status', approvalStatus);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => DriverRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setDriverApproval({
    required String driverId,
    required String status,
  }) async {
    await _client.from('drivers').update({
      'approval_status': status,
      if (status != 'approved') 'is_online': false,
      if (status != 'approved') 'is_available': false,
    }).eq('id', driverId);
    await _audit.log(
      action: 'driver.approval',
      entityType: 'drivers',
      entityId: driverId,
      summary: 'Driver approval set to $status',
      metadata: {'status': status},
    );
  }

  Future<FareConfig?> fetchActiveFare() async {
    final row = await _client
        .from('fare_config')
        .select()
        .eq('is_active', true)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return FareConfig.fromJson(row);
  }

  Future<void> updateActiveFare({
    required String id,
    required double baseFare,
    required double perKmRate,
    required double minimumFare,
  }) async {
    await _client.from('fare_config').update({
      'base_fare': baseFare,
      'per_km_rate': perKmRate,
      'minimum_fare': minimumFare,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    await _audit.log(
      action: 'fare.update',
      entityType: 'fare_config',
      entityId: id,
      summary:
          'Fare updated — base ₱${baseFare.toStringAsFixed(0)}, per km ₱${perKmRate.toStringAsFixed(0)}, min ₱${minimumFare.toStringAsFixed(0)}',
      metadata: {
        'base_fare': baseFare,
        'per_km_rate': perKmRate,
        'minimum_fare': minimumFare,
      },
    );
  }

  Future<List<AttendanceRow>> listAttendance({int limit = 50}) async {
    try {
      final rows = await _client
          .from('driver_attendance')
          .select('*, drivers(full_name, email)')
          .order('clock_in', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>)
          .map((e) => AttendanceRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<LeaveRow>> listLeaveRequests({String? status}) async {
    try {
      var query = _client
          .from('leave_requests')
          .select('*, drivers(full_name, email)');
      if (status != null) query = query.eq('status', status);
      final rows = await query.order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((e) => LeaveRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> reviewLeaveRequest({
    required String id,
    required String status,
  }) async {
    await _client.from('leave_requests').update({
      'status': status,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    await _audit.log(
      action: 'leave.review',
      entityType: 'leave_requests',
      entityId: id,
      summary: 'Leave request $status',
      metadata: {'status': status},
    );
  }

  Future<Map<String, dynamic>> fetchFleetStats() async {
    try {
      final drivers = await _client.from('drivers').select('id');
      final trips = await _client
          .from('trips')
          .select('fare')
          .eq('status', 'completed');
      final tripRows = trips as List<dynamic>;
      var earnings = 0.0;
      for (final row in tripRows) {
        earnings += ((row as Map<String, dynamic>)['fare'] as num?)?.toDouble() ?? 0;
      }
      return {
        'drivers': (drivers as List).length,
        'completedTrips': tripRows.length,
        'totalEarnings': earnings,
      };
    } catch (_) {
      return {'drivers': 0, 'completedTrips': 0, 'totalEarnings': 0.0};
    }
  }

  static const _tripColumns =
      'id, driver_id, pickup_address, dropoff_address, fare, status, created_at, completed_at, '
      'rating, review_text, complaint_tags, rating_submitted_at, review_acknowledged_at';

  Future<List<TripRow>> _fetchCompletedTrips() async {
    try {
      final rows = await _client
          .from('trips')
          .select(_tripColumns)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      final trips = (rows as List<dynamic>)
          .map((e) => TripRow.fromJson(e as Map<String, dynamic>))
          .toList();
      return _enrichTripsWithAuditRatings(trips);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw StateError(
          'Admin cannot read trips (RLS). Run fix_trips_rls.sql and fix_trip_ratings.sql in Supabase SQL Editor.',
        );
      }
      if (e.code == 'PGRST204') {
        throw StateError(
          'Trips table is missing rating columns. Run fix_trip_ratings.sql in Supabase SQL Editor.',
        );
      }
      rethrow;
    }
  }

  /// Fills in ratings from audit_logs when trip.rate was logged but trips.rating is still null.
  Future<List<TripRow>> _enrichTripsWithAuditRatings(List<TripRow> trips) async {
    final audit = await _auditRatingsByTripId();
    if (audit.isEmpty) return trips;
    return trips.map((t) {
      if (t.rating != null) return t;
      final a = audit[t.id];
      if (a == null) return t;
      return t.copyWith(
        rating: a.rating,
        reviewText: a.reviewText,
        complaintTags: a.tags,
      );
    }).toList();
  }

  Future<Map<String, ({int rating, String? reviewText, List<String> tags})>>
      _auditRatingsByTripId() async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select('entity_id, metadata, summary')
          .eq('action', 'trip.rate')
          .eq('entity_type', 'trips')
          .order('created_at', ascending: false);
      final map = <String, ({int rating, String? reviewText, List<String> tags})>{};
      final starInSummary = RegExp(r'(\d)★');
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final tripId = row['entity_id'] as String?;
        if (tripId == null || map.containsKey(tripId)) continue;
        final meta = row['metadata'];
        var rating = meta is Map ? (meta['rating'] as num?)?.toInt() : null;
        if (rating == null) {
          final summary = row['summary'] as String?;
          final match = summary != null ? starInSummary.firstMatch(summary) : null;
          if (match != null) rating = int.tryParse(match.group(1)!);
        }
        if (rating == null) continue;
        final tagsRaw = meta is Map ? meta['complaint_tags'] : null;
        final tags = tagsRaw is List
            ? tagsRaw.map((e) => e.toString()).toList()
            : <String>[];
        map[tripId] = (
          rating: rating,
          reviewText: meta is Map ? meta['review_text'] as String? : null,
          tags: tags,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _tripDay(TripRow t) => (t.completedAt ?? t.createdAt).toLocal();

  Future<FleetOverviewData> fetchFleetOverview() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final drivers = await listDrivers();
    final approved = drivers.where((d) => d.approvalStatus == 'approved').toList();
    final pending = drivers.where((d) => d.approvalStatus == 'pending').toList();
    final trips = await _fetchCompletedTrips();

    final tripsToday =
        trips.where((t) => _isSameDay(_tripDay(t), today)).length;
    final tripsYesterday =
        trips.where((t) => _isSameDay(_tripDay(t), yesterday)).length;
    final faresToday = trips
        .where((t) => _isSameDay(_tripDay(t), today))
        .fold<double>(0, (s, t) => s + t.fare);
    final avgFareToday = tripsToday > 0 ? faresToday / tripsToday : 0.0;

    final last7 = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final count = trips.where((t) => _isSameDay(_tripDay(t), day)).length;
      return DailyTripCount(date: day, count: count);
    });

    var onDuty = 0;
    try {
      final att = await listAttendance(limit: 200);
      onDuty = att.where((a) => a.isOpen).length;
    } catch (_) {}

    var onLeave = 0;
    try {
      final leaves = await listLeaveRequests(status: 'approved');
      for (final l in leaves) {
        final start = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
        final end = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
        if (!today.isBefore(start) && !today.isAfter(end)) onLeave++;
      }
    } catch (_) {}

    final offDuty = (approved.length - onDuty - onLeave).clamp(0, approved.length);

    final weekStart = today.subtract(const Duration(days: 6));
    final tripsByDriver = <String, int>{};
    for (final t in trips) {
      final day = _tripDay(t);
      if (day.isBefore(weekStart)) continue;
      final id = t.driverId;
      if (id == null) continue;
      tripsByDriver[id] = (tripsByDriver[id] ?? 0) + 1;
    }

    final topDrivers = tripsByDriver.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDriversThisWeek = topDrivers.take(5).map((e) {
      final d = drivers.cast<DriverRow?>().firstWhere(
            (x) => x?.id == e.key,
            orElse: () => null,
          );
      return (
        id: e.key,
        name: d?.fullName.isNotEmpty == true ? d!.fullName : (d?.email ?? 'Driver'),
        trips: e.value,
      );
    }).toList();

    final onboarding = OnboardingRepository(_client);

    final flagged = <FlaggedItem>[
      if (pending.isNotEmpty)
        FlaggedItem(
          title: '${pending.length} drivers pending approval',
          subtitle: 'New registrations waiting for operator review',
          borderColor: AdminTokens.pendingBorder,
          link: FlaggedLink.pending,
        ),
    ];

    try {
      final pendingLeave = await listLeaveRequests(status: 'pending');
      if (pendingLeave.isNotEmpty) {
        flagged.add(FlaggedItem(
          title: '${pendingLeave.length} unapproved leave requests',
          subtitle: 'VL and SL requests submitted recently',
          borderColor: AdminTokens.pendingBorder,
          link: FlaggedLink.leave,
        ));
      }
    } catch (_) {}

    var inactiveAdded = 0;
    final inactiveCutoff = today.subtract(const Duration(days: 3));
    for (final d in approved) {
      if (inactiveAdded >= 4) break;
      final driverTrips = trips.where((t) => t.driverId == d.id).toList();
      DateTime? lastTripDay;
      if (driverTrips.isNotEmpty) {
        lastTripDay = driverTrips.map(_tripDay).reduce((a, b) => a.isAfter(b) ? a : b);
      }
      if (lastTripDay != null && !lastTripDay.isBefore(inactiveCutoff)) continue;
      inactiveAdded++;
      flagged.add(FlaggedItem(
        title: '${d.fullName.isNotEmpty ? d.fullName : d.email} — ${lastTripDay == null ? 'no trips yet' : '${today.difference(lastTripDay).inDays} days inactive'}',
        subtitle: lastTripDay == null
            ? '0 completed trips on record'
            : 'Last trip ${lastTripDay.month}/${lastTripDay.day}',
        borderColor: AdminTokens.attentionBorder,
        driverId: d.id,
        link: FlaggedLink.driverProfile,
      ));
    }

    try {
      final expiring = await onboarding.listExpiringDocuments(withinDays: 30);
      for (final doc in expiring.take(5)) {
        final days = doc.daysUntilExpiry ?? 0;
        flagged.add(FlaggedItem(
          title: 'Document expiring in $days days',
          subtitle: '${doc.docType.label} — driver ${doc.driverId.substring(0, 8)}…',
          borderColor: AdminTokens.watch,
          driverId: doc.driverId,
          link: FlaggedLink.driverDocuments,
        ));
      }
      final expired = await onboarding.listExpiredDocuments();
      for (final doc in expired.take(5)) {
        final overdue = -(doc.daysUntilExpiry ?? 0);
        flagged.add(FlaggedItem(
          title: 'Expired document (${overdue}d overdue)',
          subtitle: doc.docType.label,
          borderColor: AdminTokens.attentionBorder,
          driverId: doc.driverId,
          link: FlaggedLink.driverDocuments,
        ));
      }
      final overdueOnboarding = await onboarding.listOverdueOnboarding();
      for (final o in overdueOnboarding.take(3)) {
        flagged.add(FlaggedItem(
          title: '${o.name} — onboarding overdue',
          subtitle: 'Stage: ${o.stage.label}',
          borderColor: AdminTokens.watch,
          driverId: o.driverId,
          link: FlaggedLink.register,
        ));
      }
      final interviews = await onboarding.listInterviewsDue();
      for (final i in interviews.take(3)) {
        flagged.add(FlaggedItem(
          title: '${i.name} — interview scheduled',
          subtitle: 'Today or overdue',
          borderColor: AdminTokens.watch,
          driverId: i.driverId,
          link: FlaggedLink.register,
        ));
      }
    } catch (_) {}

    final driversNeedingReview = <DriverReviewFlag>[];
    for (final d in approved) {
      final profile = await _buildDriverProfile(d.id, drivers: drivers, trips: trips);
      if (profile.reviewStatus == ReviewStatus.good) continue;
      final top = profile.complaintSummary.take(2).map((c) => '${c.tag} (${c.count}×)').join(', ');
      driversNeedingReview.add(DriverReviewFlag(
        driverId: d.id,
        fullName: profile.fullName,
        badgeNumber: profile.badgeNumber,
        reviewStatus: profile.reviewStatus,
        overallRating: profile.overallRating,
        reasonLine: profile.complaintsLast7d > 0
            ? '${profile.complaintsLast7d} complaints in last 7 days${top.isNotEmpty ? ' · $top' : ''}'
            : 'Overall rating ${profile.overallRating.toStringAsFixed(1)}★',
        complaintSummary: profile.complaintSummary,
      ));
    }
    driversNeedingReview.sort((a, b) {
      final order = {ReviewStatus.critical: 0, ReviewStatus.watch: 1, ReviewStatus.good: 2};
      final c = order[a.reviewStatus]!.compareTo(order[b.reviewStatus]!);
      if (c != 0) return c;
      return a.overallRating.compareTo(b.overallRating);
    });

    return FleetOverviewData(
      activeDrivers: approved.length,
      pendingApproval: pending.length,
      tripsToday: tripsToday,
      tripsYesterday: tripsYesterday,
      faresToday: faresToday,
      avgFareToday: avgFareToday,
      driversOnDuty: onDuty,
      payrollThisPeriod: null,
      payrollDriverCount: approved.length,
      tripsLast7Days: last7,
      driverStatus: DriverStatusBreakdown(
        onDuty: onDuty,
        offDuty: offDuty,
        onLeave: onLeave,
        pending: pending.length,
      ),
      flaggedItems: flagged,
      driversNeedingReview: driversNeedingReview,
      topDriversThisWeek: topDriversThisWeek,
      pendingBonusesCount: 0,
    );
  }

  Future<DriverProfile> fetchDriverProfile(String driverId) async {
    final drivers = await listDrivers();
    return _buildDriverProfile(driverId, drivers: drivers);
  }

  Future<DriverProfile> _buildDriverProfile(
    String driverId, {
    List<DriverRow>? drivers,
    List<TripRow>? trips,
  }) async {
    final allDrivers = drivers ?? await listDrivers();
    final driver = allDrivers.cast<DriverRow?>().firstWhere(
          (d) => d?.id == driverId,
          orElse: () => null,
        );
    final allTrips = trips ?? await _fetchCompletedTrips();
    final driverTrips = allTrips.where((t) => t.driverId == driverId).toList();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthTrips = driverTrips.where((t) => !_tripDay(t).isBefore(monthStart)).toList();
    final rated = driverTrips.where((t) => t.rating != null).toList();
    final ratedMonth = monthTrips.where((t) => t.rating != null).toList();

    final overall = RatingAnalytics.averageRating(rated.map((t) => t.rating)) ?? 0;
    final ratingMonth =
        RatingAnalytics.averageRating(ratedMonth.map((t) => t.rating)) ?? overall;
    final hasReviews = rated.isNotEmpty;

    final d30 = now.subtract(const Duration(days: 30));
    final d7 = now.subtract(const Duration(days: 7));
    final d14 = now.subtract(const Duration(days: 14));
    final d28 = now.subtract(const Duration(days: 28));

    final low30 = driverTrips
        .where((t) => t.rating != null && t.rating! <= 2 && !_tripDay(t).isBefore(d30))
        .length;

    final complaints7 = driverTrips
        .where((t) => !_tripDay(t).isBefore(d7))
        .expand((t) => t.complaintTags)
        .length;
    final complaintsPrev7 = driverTrips
        .where((t) {
          final day = _tripDay(t);
          return !day.isBefore(d14) && day.isBefore(d7);
        })
        .expand((t) => t.complaintTags)
        .length;

    final prior14Rated = driverTrips.where((t) {
      if (t.rating == null) return false;
      final day = _tripDay(t);
      return !day.isBefore(d28) && day.isBefore(d14);
    }).map((t) => t.rating!.toDouble());
    final prior14Avg = RatingAnalytics.averageRating(prior14Rated);

    final complaintSummary = RatingAnalytics.summarizeComplaints(
      driverTrips.expand((t) => [t.complaintTags]),
    );

    final last30Days = List.generate(30, (i) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i));
      final count = driverTrips.where((t) => _isSameDay(_tripDay(t), day)).length;
      return DailyTripCount(date: day, count: count);
    });

    final totalEarnings = driverTrips.fold<double>(0, (s, t) => s + t.fare);
    final daysInMonth = now.day.clamp(1, 31);
    final avgPerDay = monthTrips.isEmpty ? 0.0 : monthTrips.length / daysInMonth;

    final lowReviews = driverTrips
        .where((t) => t.rating != null && t.rating! <= 3)
        .map((t) => t.toAdminTripRecord())
        .toList();

    String statusLabel = 'Active';
    if (driver?.approvalStatus == 'rejected') {
      statusLabel = 'Revoked';
    } else if (driver?.approvalStatus == 'pending') {
      statusLabel = 'Pending';
    } else {
      try {
        final leaves = await listLeaveRequests(status: 'approved');
        final today = DateTime(now.year, now.month, now.day);
        final onLeave = leaves.any((l) {
          if (l.driverId != driverId) return false;
          final start = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
          final end = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
          return !today.isBefore(start) && !today.isAfter(end);
        });
        if (onLeave) statusLabel = 'On Leave';
      } catch (_) {}
    }

    String? unitNumber;
    String? assignedVehicleId;
    final expiredLabels = <String>[];
    final expiringLabels = <String>[];
    try {
      final ob = OnboardingRepository(_client);
      final docs = await ob.listDocuments(driverId);
      for (final doc in docs) {
        if (doc.status == DocumentStatus.expired) {
          expiredLabels.add(doc.docType.label);
        } else if (doc.status == DocumentStatus.expiringSoon ||
            (doc.daysUntilExpiry != null && doc.daysUntilExpiry! <= 30)) {
          expiringLabels.add(doc.docType.label);
        }
      }
      final vehicles = await _client
          .from('vehicles')
          .select()
          .eq('assigned_driver_id', driverId)
          .maybeSingle();
      if (vehicles != null) {
        unitNumber = vehicles['unit_number'] as String?;
        assignedVehicleId = vehicles['id'] as String?;
      }
    } catch (_) {}

    return DriverProfile(
      id: driverId,
      fullName: driver?.fullName.isNotEmpty == true ? driver!.fullName : 'Driver',
      badgeNumber: RatingAnalytics.driverBadge(driverId, plate: driver?.trikePlateNumber),
      statusLabel: statusLabel,
      joinedAt: driver?.startDate ?? driver?.createdAt ?? DateTime.now(),
      overallRating: overall,
      ratingThisMonth: ratingMonth,
      totalReviews: rated.length,
      lowRatingCount30d: low30,
      complaintSummary: complaintSummary,
      reviewStatus: RatingAnalytics.reviewStatus(
        overallRating: hasReviews ? overall : null,
        complaintsLast7d: complaints7,
        ratingThisMonth: ratedMonth.isEmpty ? null : ratingMonth,
        ratingPrior14d: prior14Avg,
      ),
      employmentType: driver?.employmentLabel ?? 'Contractual',
      shiftSchedule: driver?.shiftSchedule ?? '—',
      contactNumber: driver?.phone ?? '—',
      emergencyContact: driver?.emergencyContact.isNotEmpty == true
          ? driver!.emergencyContact
          : '—',
      sickLeaveRemaining: 5,
      vacationLeaveRemaining: 8,
      leaveTakenThisYear: 0,
      totalTrips: driverTrips.length,
      tripsThisMonth: monthTrips.length,
      totalEarnings: totalEarnings,
      avgTripsPerDayMonth: avgPerDay,
      tripsLast30Days: last30Days,
      recentTrips: driverTrips.take(10).map((t) => t.toAdminTripRecord()).toList(),
      lowRatingReviews: lowReviews.take(5).toList(),
      complaintsLast7d: complaints7,
      complaintsPrev7d: complaintsPrev7,
      activityLog: (await _audit.fetchLogsForDriver(driverId))
          .map((e) => ActivityLogEntry(date: e.createdAt, action: e.summary))
          .toList(),
      email: driver?.email,
      plate: driver?.trikePlateNumber,
      station: driver?.station ?? 'Carmona Central',
      unitNumber: unitNumber,
      expiredDocumentLabels: expiredLabels,
      expiringSoonDocumentLabels: expiringLabels,
      assignedVehicleId: assignedVehicleId,
    );
  }

  Future<int> tripsThisWeekForDriver(String driverId) async {
    final trips = await _fetchCompletedTrips();
    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    return trips.where((t) {
      if (t.driverId != driverId) return false;
      return !_tripDay(t).isBefore(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
      );
    }).length;
  }

  Future<Map<String, int>> fetchWeeklyTripsByDriver() async {
    final trips = await _fetchCompletedTrips();
    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final map = <String, int>{};
    for (final t in trips) {
      final id = t.driverId;
      if (id == null || _tripDay(t).isBefore(start)) continue;
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  Future<void> acknowledgeTripReview(String tripId) async {
    await _client.from('trips').update({
      'review_acknowledged_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', tripId);
    await _audit.log(
      action: 'trip.review_acknowledge',
      entityType: 'trips',
      entityId: tripId,
      summary: 'Trip review acknowledged',
    );
  }

  Future<DriverRow?> fetchDriver(String driverId) async {
    final row = await _client.from('drivers').select().eq('id', driverId).maybeSingle();
    if (row == null) return null;
    return DriverRow.fromJson(row);
  }

  Future<void> updateDriverShift({
    required String driverId,
    required Map<String, dynamic> payload,
  }) async {
    await _client.from('drivers').update(payload).eq('id', driverId);
    await _audit.log(
      action: 'driver.shift_update',
      entityType: 'drivers',
      entityId: driverId,
      summary: 'Driver shift schedule updated',
      metadata: payload,
    );
  }

  Future<List<AuditLogRow>> fetchAuditLogs({int limit = 100}) =>
      _audit.fetchLogs(limit: limit);
}
