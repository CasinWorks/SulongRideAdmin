import 'package:flutter/material.dart';

enum ReviewStatus { good, watch, critical }

enum TripStatus { completed, cancelled, ongoing }

class ComplaintCount {
  const ComplaintCount({required this.tag, required this.count});

  final String tag;
  final int count;
}

class TripRecord {
  const TripRecord({
    required this.id,
    required this.date,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.durationMinutes,
    required this.status,
    this.rating,
    this.reviewText,
    this.complaintTags = const [],
    this.reviewAcknowledged = false,
  });

  final String id;
  final DateTime date;
  final String pickup;
  final String dropoff;
  final double fare;
  final int durationMinutes;
  final TripStatus status;
  final double? rating;
  final String? reviewText;
  final List<String> complaintTags;
  final bool reviewAcknowledged;

  TripRecord copyWith({
    bool? reviewAcknowledged,
    double? rating,
  }) =>
      TripRecord(
        id: id,
        date: date,
        pickup: pickup,
        dropoff: dropoff,
        fare: fare,
        durationMinutes: durationMinutes,
        status: status,
        rating: rating ?? this.rating,
        reviewText: reviewText,
        complaintTags: complaintTags,
        reviewAcknowledged: reviewAcknowledged ?? this.reviewAcknowledged,
      );
}

class DailyTripCount {
  const DailyTripCount({required this.date, required this.count});

  final DateTime date;
  final int count;
}

class DriverStatusBreakdown {
  const DriverStatusBreakdown({
    required this.onDuty,
    required this.offDuty,
    required this.onLeave,
    required this.pending,
  });

  final int onDuty;
  final int offDuty;
  final int onLeave;
  final int pending;

  int get total => onDuty + offDuty + onLeave + pending;
}

class FlaggedItem {
  const FlaggedItem({
    required this.title,
    required this.subtitle,
    required this.borderColor,
    this.onTap,
    this.driverId,
    this.link = FlaggedLink.none,
  });

  final String title;
  final String subtitle;
  final Color borderColor;
  final VoidCallback? onTap;
  final String? driverId;
  final FlaggedLink link;
}

enum FlaggedLink {
  none,
  pending,
  leave,
  driverProfile,
  driverDocuments,
  driverHr,
  register,
  payroll,
  disciplinary,
}

class DriverReviewFlag {
  const DriverReviewFlag({
    required this.driverId,
    required this.fullName,
    required this.badgeNumber,
    required this.reviewStatus,
    required this.overallRating,
    required this.reasonLine,
    required this.complaintSummary,
  });

  final String driverId;
  final String fullName;
  final String badgeNumber;
  final ReviewStatus reviewStatus;
  final double overallRating;
  final String reasonLine;
  final List<ComplaintCount> complaintSummary;
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.date,
    required this.action,
  });

  final DateTime date;
  final String action;
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.fullName,
    required this.badgeNumber,
    required this.statusLabel,
    required this.joinedAt,
    required this.overallRating,
    required this.ratingThisMonth,
    required this.totalReviews,
    required this.lowRatingCount30d,
    required this.complaintSummary,
    required this.reviewStatus,
    required this.employmentType,
    required this.shiftSchedule,
    required this.contactNumber,
    required this.emergencyContact,
    required this.sickLeaveRemaining,
    required this.vacationLeaveRemaining,
    required this.leaveTakenThisYear,
    required this.totalTrips,
    required this.tripsThisMonth,
    required this.totalEarnings,
    required this.avgTripsPerDayMonth,
    required this.tripsLast30Days,
    required this.recentTrips,
    required this.lowRatingReviews,
    required this.complaintsLast7d,
    required this.complaintsPrev7d,
    required this.activityLog,
    this.email,
    this.plate,
    this.station = 'Carmona Central',
    this.unitNumber,
    this.expiredDocumentLabels = const [],
    this.expiringSoonDocumentLabels = const [],
    this.assignedVehicleId,
  });

  final String id;
  final String fullName;
  final String badgeNumber;
  final String statusLabel;
  final DateTime joinedAt;
  final double overallRating;
  final double ratingThisMonth;
  final int totalReviews;
  final int lowRatingCount30d;
  final List<ComplaintCount> complaintSummary;
  final ReviewStatus reviewStatus;
  final String employmentType;
  final String shiftSchedule;
  final String contactNumber;
  final String emergencyContact;
  final int sickLeaveRemaining;
  final int vacationLeaveRemaining;
  final int leaveTakenThisYear;
  final int totalTrips;
  final int tripsThisMonth;
  final double totalEarnings;
  final double avgTripsPerDayMonth;
  final List<DailyTripCount> tripsLast30Days;
  final List<TripRecord> recentTrips;
  final List<TripRecord> lowRatingReviews;
  final int complaintsLast7d;
  final int complaintsPrev7d;
  final List<ActivityLogEntry> activityLog;
  final String? email;
  final String? plate;
  final String station;
  final String? unitNumber;
  final List<String> expiredDocumentLabels;
  final List<String> expiringSoonDocumentLabels;
  final String? assignedVehicleId;

  double get lowRatingPercent30d =>
      tripsThisMonth > 0 ? (lowRatingCount30d / tripsThisMonth) * 100 : 0;
}

class FleetOverviewData {
  const FleetOverviewData({
    required this.activeDrivers,
    required this.pendingApproval,
    required this.tripsToday,
    required this.tripsYesterday,
    required this.faresToday,
    required this.avgFareToday,
    required this.driversOnDuty,
    required this.payrollThisPeriod,
    required this.payrollDriverCount,
    required this.tripsLast7Days,
    required this.driverStatus,
    required this.flaggedItems,
    required this.driversNeedingReview,
    required this.topDriversThisWeek,
    this.pendingBonusesCount = 0,
  });

  final int activeDrivers;
  final int pendingApproval;
  final int tripsToday;
  final int tripsYesterday;
  final double faresToday;
  final double avgFareToday;
  final int driversOnDuty;
  final double? payrollThisPeriod;
  final int payrollDriverCount;
  final List<DailyTripCount> tripsLast7Days;
  final DriverStatusBreakdown driverStatus;
  final List<FlaggedItem> flaggedItems;
  final List<DriverReviewFlag> driversNeedingReview;
  final List<({String id, String name, int trips})> topDriversThisWeek;
  final int pendingBonusesCount;
}
