import 'package:flutter/material.dart';

import '../core/theme/admin_tokens.dart';
import '../models/admin_models.dart';
import '../models/driver_row.dart';

abstract final class MockAdminData {
  static const mockDriverIds = [
    'mock-roberto-garcia',
    'mock-maria-santos',
    'mock-juan-dela-cruz',
    'mock-ana-reyes',
    'mock-miguel-torres',
  ];

  static List<DailyTripCount> last7Days() {
    final today = DateTime.now();
    const counts = [18, 22, 15, 28, 24, 31, 26];
    return List.generate(7, (i) {
      return DailyTripCount(
        date: today.subtract(Duration(days: 6 - i)),
        count: counts[i],
      );
    });
  }

  static List<DailyTripCount> last30Days({int base = 4}) {
    final today = DateTime.now();
    return List.generate(30, (i) {
      return DailyTripCount(
        date: today.subtract(Duration(days: 29 - i)),
        count: base + (i % 5),
      );
    });
  }

  static List<TripRecord> sampleTrips({double ratingBias = 0}) {
    final trips = [
      TripRecord(
        id: 't1',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        pickup: 'Carmona Public Market',
        dropoff: 'Southwoods Exit',
        fare: 45,
        durationMinutes: 18,
        status: TripStatus.completed,
        rating: 5,
        reviewText: 'Mabait na driver, maayos ang byahe.',
      ),
      TripRecord(
        id: 't2',
        date: DateTime.now().subtract(const Duration(hours: 5)),
        pickup: 'Vista Mall Carmona',
        dropoff: 'Milagrosa',
        fare: 40,
        durationMinutes: 12,
        status: TripStatus.completed,
        rating: 4,
      ),
      TripRecord(
        id: 't3',
        date: DateTime.now().subtract(const Duration(days: 1)),
        pickup: 'Carmona Town Plaza',
        dropoff: 'Lantic',
        fare: 55,
        durationMinutes: 22,
        status: TripStatus.completed,
        rating: 2,
        reviewText: 'Ang tagal dumating, parang nagmamadali sa dulo.',
        complaintTags: ['Late arrival', 'Speeding / unsafe'],
      ),
      TripRecord(
        id: 't4',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        pickup: 'Southville 2',
        dropoff: 'Carmona Public Market',
        fare: 40,
        durationMinutes: 15,
        status: TripStatus.cancelled,
      ),
      TripRecord(
        id: 't5',
        date: DateTime.now().subtract(const Duration(days: 2)),
        pickup: 'Malabanan',
        dropoff: 'Vista Mall Carmona',
        fare: 48,
        durationMinutes: 16,
        status: TripStatus.completed,
        rating: 5,
      ),
      TripRecord(
        id: 't6',
        date: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
        pickup: 'Carmona Exit',
        dropoff: 'Mabuhay',
        fare: 42,
        durationMinutes: 14,
        status: TripStatus.completed,
        rating: 3,
        reviewText: 'Okay lang, medyo maingay ang makina.',
        complaintTags: ['Vehicle condition'],
      ),
      TripRecord(
        id: 't7',
        date: DateTime.now().subtract(const Duration(days: 3)),
        pickup: 'Lantic',
        dropoff: 'Carmona Town Plaza',
        fare: 40,
        durationMinutes: 11,
        status: TripStatus.completed,
        rating: 1,
        reviewText: 'Sobrang bilis mag-drive, nakakatakot. Hindi ko bet.',
        complaintTags: ['Speeding / unsafe', 'Rude behavior'],
      ),
      TripRecord(
        id: 't8',
        date: DateTime.now().subtract(const Duration(days: 4)),
        pickup: 'Milagrosa',
        dropoff: 'Southwoods',
        fare: 52,
        durationMinutes: 19,
        status: TripStatus.completed,
        rating: 4,
      ),
      TripRecord(
        id: 't9',
        date: DateTime.now().subtract(const Duration(days: 5)),
        pickup: 'Carmona Public Market',
        dropoff: 'Vista Mall Carmona',
        fare: 40,
        durationMinutes: 10,
        status: TripStatus.completed,
      ),
      TripRecord(
        id: 't10',
        date: DateTime.now().subtract(const Duration(days: 6)),
        pickup: 'Mabuhay',
        dropoff: 'Malabanan',
        fare: 44,
        durationMinutes: 13,
        status: TripStatus.completed,
        rating: 5,
        reviewText: 'Salamat kuya, safe trip!',
      ),
    ];
    if (ratingBias == 0) return trips;
    return trips
        .map((t) => t.rating != null
            ? t.copyWith(rating: (t.rating! + ratingBias).clamp(1, 5))
            : t)
        .toList();
  }

  static DriverProfile profileForId(String id, {DriverRow? row}) {
    final templates = {
      mockDriverIds[0]: _roberto(),
      mockDriverIds[1]: _maria(),
      mockDriverIds[2]: _juan(),
      mockDriverIds[3]: _ana(),
      mockDriverIds[4]: _miguel(),
    };

    final base = templates[id] ?? templates[mockDriverIds[id.hashCode.abs() % 5]]!;
    if (row == null) return base.copyWithId(id);

    return base.copyWithId(
      id,
      fullName: row.fullName.isNotEmpty ? row.fullName : base.fullName,
      statusLabel: _statusFromApproval(row.approvalStatus),
      joinedAt: row.createdAt ?? base.joinedAt,
      email: row.email,
      plate: row.trikePlateNumber,
      contactNumber: row.phone,
    );
  }

  static String _statusFromApproval(String status) => switch (status) {
        'approved' => 'Active',
        'rejected' => 'Revoked',
        'pending' => 'Pending',
        _ => 'Active',
      };

  static FleetOverviewData overview({
    int pendingApproval = 3,
    VoidCallback? onPendingTap,
    VoidCallback? onLeaveTap,
  }) {
    final roberto = _roberto();
    final maria = _maria();
    return FleetOverviewData(
      activeDrivers: 12,
      pendingApproval: pendingApproval,
      tripsToday: 26,
      tripsYesterday: 22,
      faresToday: 1120,
      avgFareToday: 43,
      driversOnDuty: 7,
      payrollThisPeriod: null,
      payrollDriverCount: 12,
      tripsLast7Days: last7Days(),
      driverStatus: const DriverStatusBreakdown(
        onDuty: 7,
        offDuty: 3,
        onLeave: 2,
        pending: 3,
      ),
      flaggedItems: [
        FlaggedItem(
          title: '$pendingApproval drivers pending approval',
          subtitle: 'New registrations waiting for operator review',
          borderColor: AdminTokens.pendingBorder,
          onTap: onPendingTap,
        ),
        FlaggedItem(
          title: '2 unapproved leave requests',
          subtitle: 'VL and SL requests submitted this week',
          borderColor: AdminTokens.pendingBorder,
          onTap: onLeaveTap,
        ),
        FlaggedItem(
          title: 'Ana Reyes — 3 days inactive',
          subtitle: '0 trips since ${DateTime.now().subtract(const Duration(days: 3)).month}/${DateTime.now().subtract(const Duration(days: 3)).day}',
          borderColor: AdminTokens.attentionBorder,
        ),
        FlaggedItem(
          title: 'Miguel Torres — 4 days inactive',
          subtitle: 'Last trip: Carmona Public Market → Milagrosa',
          borderColor: AdminTokens.attentionBorder,
        ),
      ],
      driversNeedingReview: [
        DriverReviewFlag(
          driverId: roberto.id,
          fullName: roberto.fullName,
          badgeNumber: roberto.badgeNumber,
          reviewStatus: ReviewStatus.critical,
          overallRating: roberto.overallRating,
          reasonLine:
              '4 complaints in last 7 days · Rude behavior (3×), Speeding (1×)',
          complaintSummary: roberto.complaintSummary,
        ),
        DriverReviewFlag(
          driverId: maria.id,
          fullName: maria.fullName,
          badgeNumber: maria.badgeNumber,
          reviewStatus: ReviewStatus.watch,
          overallRating: maria.overallRating,
          reasonLine:
              'Rating dropped 0.6 in last 14 days · Late arrival (2×)',
          complaintSummary: maria.complaintSummary,
        ),
      ],
      topDriversThisWeek: const [
        (id: 'mock-juan-dela-cruz', name: 'Juan Dela Cruz', trips: 38),
        (id: 'mock-ana-reyes', name: 'Ana Reyes', trips: 31),
        (id: 'mock-maria-santos', name: 'Maria Santos', trips: 27),
        (id: 'mock-roberto-garcia', name: 'Roberto Garcia', trips: 19),
      ],
    );
  }

  static DriverProfile _roberto() {
    final trips = sampleTrips();
    return DriverProfile(
      id: mockDriverIds[0],
      fullName: 'Roberto Garcia',
      badgeNumber: 'DRV-1042',
      statusLabel: 'Active',
      joinedAt: DateTime(2024, 3, 12),
      overallRating: 3.1,
      ratingThisMonth: 2.9,
      totalReviews: 87,
      lowRatingCount30d: 6,
      complaintSummary: const [
        ComplaintCount(tag: 'Rude behavior', count: 3),
        ComplaintCount(tag: 'Speeding / unsafe', count: 2),
        ComplaintCount(tag: 'Late arrival', count: 1),
      ],
      reviewStatus: ReviewStatus.critical,
      employmentType: 'Company-employed',
      shiftSchedule: 'Mon–Sat · 6:00 AM – 2:00 PM',
      contactNumber: '0917 555 0142',
      emergencyContact: 'Rosa Garcia (spouse) · 0918 222 8891',
      sickLeaveRemaining: 5,
      vacationLeaveRemaining: 8,
      leaveTakenThisYear: 4,
      totalTrips: 412,
      tripsThisMonth: 68,
      totalEarnings: 18420,
      avgTripsPerDayMonth: 3.4,
      tripsLast30Days: last30Days(base: 2),
      recentTrips: trips,
      lowRatingReviews: trips.where((t) => (t.rating ?? 5) <= 3).toList(),
      complaintsLast7d: 4,
      complaintsPrev7d: 1,
      activityLog: [
        ActivityLogEntry(
          date: DateTime.now().subtract(const Duration(days: 3)),
          action: 'Leave request approved (VL, 2 days)',
        ),
        ActivityLogEntry(
          date: DateTime.now().subtract(const Duration(days: 120)),
          action: 'Account approved by operator',
        ),
      ],
      email: 'roberto.garcia@example.com',
      plate: 'CAV 4521',
    );
  }

  static DriverProfile _maria() {
    final trips = sampleTrips(ratingBias: -0.8);
    return DriverProfile(
      id: mockDriverIds[1],
      fullName: 'Maria Santos',
      badgeNumber: 'DRV-1028',
      statusLabel: 'On Leave',
      joinedAt: DateTime(2024, 1, 8),
      overallRating: 3.8,
      ratingThisMonth: 3.7,
      totalReviews: 124,
      lowRatingCount30d: 3,
      complaintSummary: const [
        ComplaintCount(tag: 'Late arrival', count: 2),
        ComplaintCount(tag: 'Vehicle condition', count: 1),
      ],
      reviewStatus: ReviewStatus.watch,
      employmentType: 'Company-employed',
      shiftSchedule: 'Mon–Fri · 2:00 PM – 10:00 PM',
      contactNumber: '0928 441 1028',
      emergencyContact: 'Pedro Santos (brother) · 0917 333 7712',
      sickLeaveRemaining: 3,
      vacationLeaveRemaining: 5,
      leaveTakenThisYear: 7,
      totalTrips: 528,
      tripsThisMonth: 54,
      totalEarnings: 22100,
      avgTripsPerDayMonth: 2.7,
      tripsLast30Days: last30Days(base: 3),
      recentTrips: trips,
      lowRatingReviews: trips.where((t) => (t.rating ?? 5) <= 3).take(3).toList(),
      complaintsLast7d: 2,
      complaintsPrev7d: 0,
      activityLog: [
        ActivityLogEntry(
          date: DateTime.now().subtract(const Duration(days: 1)),
          action: 'VL approved — on leave until Friday',
        ),
      ],
      email: 'maria.santos@example.com',
      plate: 'CAV 8892',
    );
  }

  static DriverProfile _juan() {
    final trips = sampleTrips(ratingBias: 0.5);
    return DriverProfile(
      id: mockDriverIds[2],
      fullName: 'Juan Dela Cruz',
      badgeNumber: 'DRV-1001',
      statusLabel: 'Active',
      joinedAt: DateTime(2023, 11, 20),
      overallRating: 4.7,
      ratingThisMonth: 4.8,
      totalReviews: 203,
      lowRatingCount30d: 1,
      complaintSummary: const [ComplaintCount(tag: 'Late arrival', count: 1)],
      reviewStatus: ReviewStatus.good,
      employmentType: 'Company-employed',
      shiftSchedule: 'Mon–Sat · 6:00 AM – 2:00 PM',
      contactNumber: '0915 882 1001',
      emergencyContact: 'Elena Dela Cruz (mother) · 0920 111 4455',
      sickLeaveRemaining: 6,
      vacationLeaveRemaining: 10,
      leaveTakenThisYear: 2,
      totalTrips: 891,
      tripsThisMonth: 92,
      totalEarnings: 38400,
      avgTripsPerDayMonth: 4.6,
      tripsLast30Days: last30Days(base: 5),
      recentTrips: trips,
      lowRatingReviews: const [],
      complaintsLast7d: 0,
      complaintsPrev7d: 0,
      activityLog: [
        ActivityLogEntry(
          date: DateTime.now().subtract(const Duration(days: 7)),
          action: 'Achievement: 800 trips milestone',
        ),
      ],
      email: 'juan.delacruz@example.com',
      plate: 'CAV 1001',
    );
  }

  static DriverProfile _ana() => DriverProfile(
        id: mockDriverIds[3],
        fullName: 'Ana Reyes',
        badgeNumber: 'DRV-1035',
        statusLabel: 'Active',
        joinedAt: DateTime(2024, 5, 2),
        overallRating: 4.2,
        ratingThisMonth: 4.1,
        totalReviews: 56,
        lowRatingCount30d: 2,
        complaintSummary: const [ComplaintCount(tag: 'Wrong route', count: 1)],
        reviewStatus: ReviewStatus.good,
        employmentType: 'Company-employed',
        shiftSchedule: 'Tue–Sun · 10:00 AM – 6:00 PM',
        contactNumber: '0939 221 1035',
        emergencyContact: 'Lito Reyes (father) · 0917 888 2200',
        sickLeaveRemaining: 4,
        vacationLeaveRemaining: 7,
        leaveTakenThisYear: 3,
        totalTrips: 245,
        tripsThisMonth: 31,
        totalEarnings: 10200,
        avgTripsPerDayMonth: 1.5,
        tripsLast30Days: last30Days(base: 1),
        recentTrips: sampleTrips(),
        lowRatingReviews: const [],
        complaintsLast7d: 0,
        complaintsPrev7d: 0,
        activityLog: const [],
        email: 'ana.reyes@example.com',
        plate: 'CAV 3310',
      );

  static DriverProfile _miguel() => DriverProfile(
        id: mockDriverIds[4],
        fullName: 'Miguel Torres',
        badgeNumber: 'DRV-1051',
        statusLabel: 'Active',
        joinedAt: DateTime(2024, 7, 15),
        overallRating: 4.0,
        ratingThisMonth: 3.9,
        totalReviews: 34,
        lowRatingCount30d: 2,
        complaintSummary: const [ComplaintCount(tag: 'Overcharging', count: 1)],
        reviewStatus: ReviewStatus.good,
        employmentType: 'Company-employed',
        shiftSchedule: 'Mon–Sat · 2:00 PM – 10:00 PM',
        contactNumber: '0916 773 1051',
        emergencyContact: 'Carmen Torres (mother) · 0922 445 9911',
        sickLeaveRemaining: 5,
        vacationLeaveRemaining: 9,
        leaveTakenThisYear: 1,
        totalTrips: 156,
        tripsThisMonth: 22,
        totalEarnings: 6800,
        avgTripsPerDayMonth: 1.1,
        tripsLast30Days: last30Days(base: 1),
        recentTrips: sampleTrips(),
        lowRatingReviews: const [],
        complaintsLast7d: 1,
        complaintsPrev7d: 0,
        activityLog: const [],
        email: 'miguel.torres@example.com',
        plate: 'CAV 5512',
      );
}

extension on DriverProfile {
  DriverProfile copyWithId(
    String newId, {
    String? fullName,
    String? statusLabel,
    DateTime? joinedAt,
    String? email,
    String? plate,
    String? contactNumber,
  }) {
    return DriverProfile(
      id: newId,
      fullName: fullName ?? this.fullName,
      badgeNumber: badgeNumber,
      statusLabel: statusLabel ?? this.statusLabel,
      joinedAt: joinedAt ?? this.joinedAt,
      overallRating: overallRating,
      ratingThisMonth: ratingThisMonth,
      totalReviews: totalReviews,
      lowRatingCount30d: lowRatingCount30d,
      complaintSummary: complaintSummary,
      reviewStatus: reviewStatus,
      employmentType: employmentType,
      shiftSchedule: shiftSchedule,
      contactNumber: contactNumber ?? this.contactNumber,
      emergencyContact: emergencyContact,
      sickLeaveRemaining: sickLeaveRemaining,
      vacationLeaveRemaining: vacationLeaveRemaining,
      leaveTakenThisYear: leaveTakenThisYear,
      totalTrips: totalTrips,
      tripsThisMonth: tripsThisMonth,
      totalEarnings: totalEarnings,
      avgTripsPerDayMonth: avgTripsPerDayMonth,
      tripsLast30Days: tripsLast30Days,
      recentTrips: recentTrips,
      lowRatingReviews: lowRatingReviews,
      complaintsLast7d: complaintsLast7d,
      complaintsPrev7d: complaintsPrev7d,
      activityLog: activityLog,
      email: email ?? this.email,
      plate: plate ?? this.plate,
    );
  }
}
