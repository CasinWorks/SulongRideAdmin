import '../models/admin_models.dart';

/// Shared rating analytics — computed from trip rows, not stored on drivers.
abstract final class RatingAnalytics {
  static const complaintTags = [
    'Rude behavior',
    'Speeding / unsafe',
    'Late arrival',
    'Overcharging',
    'Vehicle condition',
    'Wrong route',
  ];

  static double? averageRating(Iterable<num?> ratings) {
    final values = ratings.whereType<num>().map((e) => e.toDouble()).toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static ReviewStatus reviewStatus({
    required double? overallRating,
    required int complaintsLast7d,
    required double? ratingThisMonth,
    required double? ratingPrior14d,
  }) {
    final overall = overallRating ?? 5.0;
    if (overall < 3.5 || complaintsLast7d >= 3) return ReviewStatus.critical;
    if (overall < 4.0) return ReviewStatus.watch;
    if (ratingThisMonth != null &&
        ratingPrior14d != null &&
        ratingThisMonth < ratingPrior14d - 0.5) {
      return ReviewStatus.watch;
    }
    return ReviewStatus.good;
  }

  static List<ComplaintCount> summarizeComplaints(Iterable<List<String>> tagLists) {
    final counts = <String, int>{};
    for (final tags in tagLists) {
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts.entries
        .map((e) => ComplaintCount(tag: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  static String driverBadge(String driverId, {String? plate}) {
    if (plate != null && plate.isNotEmpty) return plate;
    final short = driverId.replaceAll('-', '').toUpperCase();
    return 'DRV-${short.length >= 4 ? short.substring(0, 4) : short}';
  }
}

class TripRow {
  TripRow({
    required this.id,
    required this.driverId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.reviewText,
    this.complaintTags = const [],
    this.reviewAcknowledgedAt,
  });

  final String id;
  final String? driverId;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? rating;
  final String? reviewText;
  final List<String> complaintTags;
  final DateTime? reviewAcknowledgedAt;

  bool get isReviewAcknowledged => reviewAcknowledgedAt != null;

  int get durationMinutes {
    final end = completedAt ?? createdAt;
    final mins = end.difference(createdAt).inMinutes;
    return mins < 1 ? 1 : mins;
  }

  factory TripRow.fromJson(Map<String, dynamic> json) {
    final tags = json['complaint_tags'];
    return TripRow(
      id: json['id'] as String,
      driverId: json['driver_id'] as String?,
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      rating: (json['rating'] as num?)?.toInt(),
      reviewText: json['review_text'] as String?,
      complaintTags: tags is List
          ? tags.map((e) => e.toString()).toList()
          : const [],
      reviewAcknowledgedAt: json['review_acknowledged_at'] != null
          ? DateTime.tryParse(json['review_acknowledged_at'] as String)
          : null,
    );
  }

  TripRow copyWith({
    int? rating,
    String? reviewText,
    List<String>? complaintTags,
  }) =>
      TripRow(
        id: id,
        driverId: driverId,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        fare: fare,
        status: status,
        createdAt: createdAt,
        completedAt: completedAt,
        rating: rating ?? this.rating,
        reviewText: reviewText ?? this.reviewText,
        complaintTags: complaintTags ?? this.complaintTags,
        reviewAcknowledgedAt: reviewAcknowledgedAt,
      );

  TripRecord toAdminTripRecord() {
    return TripRecord(
      id: id,
      date: completedAt ?? createdAt,
      pickup: pickupAddress,
      dropoff: dropoffAddress,
      fare: fare,
      durationMinutes: durationMinutes,
      status: switch (status) {
        'cancelled' => TripStatus.cancelled,
        'ongoing' || 'accepted' => TripStatus.ongoing,
        _ => TripStatus.completed,
      },
      rating: rating?.toDouble(),
      reviewText: reviewText,
      complaintTags: complaintTags,
      reviewAcknowledged: isReviewAcknowledged,
    );
  }
}
