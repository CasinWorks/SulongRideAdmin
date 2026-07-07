double jsonToDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Active fare row from `fare_config`.
// TODO: VERIFY DATA SHAPE — confirm column names/types match Supabase `fare_config`.
class FareConfig {
  const FareConfig({
    required this.id,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumFare,
    required this.currency,
    required this.isActive,
  });

  /// Used when Supabase fare_config is slow or unavailable so home UI still renders.
  static const fallback = FareConfig(
    id: 'fallback',
    baseFare: 40,
    perKmRate: 0,
    minimumFare: 40,
    currency: 'PHP',
    isActive: true,
  );

  final String id;
  final double baseFare;
  final double perKmRate;
  final double minimumFare;
  final String currency;
  final bool isActive;

  factory FareConfig.fromJson(Map<String, dynamic> json) {
    return FareConfig(
      id: json['id'] as String,
      baseFare: jsonToDouble(json['base_fare']),
      perKmRate: jsonToDouble(json['per_km_rate']),
      minimumFare: jsonToDouble(json['minimum_fare']),
      currency: json['currency'] as String? ?? 'PHP',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  double computeFare(double distanceKm) {
    final raw = baseFare + (distanceKm * perKmRate);
    return raw < minimumFare ? minimumFare : raw;
  }
}

/// Trip row from `trips`.
// TODO: VERIFY DATA SHAPE — confirm columns/status values match Supabase `trips`.
class TripModel {
  const TripModel({
    required this.id,
    required this.riderId,
    this.driverId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    required this.fare,
    this.distanceKm,
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.reviewText,
    this.complaintTags = const [],
    this.ratingSubmittedAt,
  });

  final String id;
  final String riderId;
  final String? driverId;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String status;
  final double fare;
  final double? distanceKm;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? rating;
  final String? reviewText;
  final List<String> complaintTags;
  final DateTime? ratingSubmittedAt;

  bool get isTerminal => status == 'completed' || status == 'cancelled';
  bool get hasRating => rating != null;

  static List<String> _parseTags(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      riderId: json['rider_id'] as String,
      driverId: json['driver_id'] as String?,
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'requested',
      fare: jsonToDouble(json['fare']),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ??
          (json['distance'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      rating: (json['rating'] as num?)?.toInt(),
      reviewText: json['review_text'] as String?,
      complaintTags: _parseTags(json['complaint_tags']),
      ratingSubmittedAt: json['rating_submitted_at'] != null
          ? DateTime.tryParse(json['rating_submitted_at'] as String)
          : null,
    );
  }
}
