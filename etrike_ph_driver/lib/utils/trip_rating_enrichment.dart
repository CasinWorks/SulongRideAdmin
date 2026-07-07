import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_model.dart';

typedef AuditTripRating = ({int rating, String? reviewText, List<String> tags});

/// Passenger ratings from audit_logs when [trips.rating] is still null.
Future<Map<String, AuditTripRating>> fetchAuditRatingsByTripId(
  SupabaseClient client,
) async {
  try {
    final rows = await client
        .from('audit_logs')
        .select('entity_id, metadata, summary')
        .eq('action', 'trip.rate')
        .eq('entity_type', 'trips')
        .order('created_at', ascending: false);

    final map = <String, AuditTripRating>{};
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
      if (rating == null || rating < 1 || rating > 5) continue;

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

TripModel enrichTripWithAuditRating(
  TripModel trip,
  Map<String, AuditTripRating> audit,
) {
  if (trip.rating != null) return trip;
  final a = audit[trip.id];
  if (a == null) return trip;
  return TripModel(
    id: trip.id,
    riderId: trip.riderId,
    driverId: trip.driverId,
    pickupAddress: trip.pickupAddress,
    dropoffAddress: trip.dropoffAddress,
    pickupLat: trip.pickupLat,
    pickupLng: trip.pickupLng,
    dropoffLat: trip.dropoffLat,
    dropoffLng: trip.dropoffLng,
    status: trip.status,
    fare: trip.fare,
    distanceKm: trip.distanceKm,
    createdAt: trip.createdAt,
    completedAt: trip.completedAt,
    rating: a.rating,
    reviewText: a.reviewText ?? trip.reviewText,
    complaintTags: a.tags.isNotEmpty ? a.tags : trip.complaintTags,
    ratingSubmittedAt: trip.ratingSubmittedAt,
  );
}

List<TripModel> enrichTripsWithAuditRatings(
  List<TripModel> trips,
  Map<String, AuditTripRating> audit,
) =>
    trips.map((t) => enrichTripWithAuditRating(t, audit)).toList();
