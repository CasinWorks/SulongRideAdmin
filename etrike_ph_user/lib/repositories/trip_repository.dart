import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/keys.dart';
import '../core/constants/map_regions.dart';
import '../models/trip_model.dart';
import 'audit_repository.dart';
import 'auth_repository.dart';

List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;
    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

class TripRepository {
  TripRepository(this._client, this._dio, this._auth)
      : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final Dio _dio;
  final AuthRepository _auth;
  final AuditRepository _audit;

  Future<FareConfig> fetchActiveFareConfig() async {
    try {
      final data = await _client
          .from('effective_fare_config')
          .select()
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (data == null) {
        throw StateError('No effective fare row found.');
      }
      return FareConfig.fromJson(data);
    } catch (_) {
      return FareConfig.fallback;
    }
  }

  void _ensureGoogleApiOk(Map<String, dynamic>? data, String apiName) {
    if (data == null) {
      throw StateError(
        '$apiName: empty response from Google. Check device internet access.',
      );
    }
    final status = data['status'] as String?;
    if (status == null) {
      throw StateError(
        '$apiName: unexpected response from Google (missing status).',
      );
    }
    if (status == 'OK' || status == 'ZERO_RESULTS') return;
    final message = data['error_message'] as String? ?? status;
    throw StateError(_friendlyGoogleApiError(apiName, message));
  }

  String _friendlyGoogleApiError(String apiName, String message) {
    final blocked = message.contains('not authorized to use this API key') ||
        message.contains('not authorized') ||
        message.contains('API keys with referer restrictions');
    if (blocked ||
        (googleMapsNativeApiKey == googleMapsWebServicesApiKey &&
            message.contains('referer'))) {
      return '$apiName: API key blocked for destination search.\n'
          'Create a second key in Google Cloud with Application restriction = None '
          '(API-restricted to Places API, Geocoding API, Directions API) and set '
          'googleMapsWebServicesApiKey in keys.dart. Keep the iOS-restricted map key only in Info.plist.';
    }
    if (message.contains('billing') ||
        message.contains('enable') && message.contains('API')) {
      return '$apiName: $message\n'
          'In Google Cloud: enable billing, then enable Places API, Geocoding API, and Directions API.';
    }
    return '$apiName: $message';
  }

  Future<List<Map<String, dynamic>>> _autocompleteRequest(
    String input, {
    LatLng? near,
    required bool localBias,
  }) async {
    final params = <String, String>{
      'input': input,
      'key': googleMapsWebServicesApiKey,
      'components': 'country:ph',
    };
    if (localBias) {
      final bias = near ?? MapRegions.carmonaCenter;
      params['types'] = 'geocode';
      params['location'] = '${bias.latitude},${bias.longitude}';
      params['radius'] = '${MapRegions.searchRadiusMeters}';
      params['strictbounds'] = 'false';
    }
    final response = await _dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: params,
    );
    final data = response.data;
    _ensureGoogleApiOk(data, 'Places Autocomplete');
    final preds = data?['predictions'];
    if (preds is List) {
      return preds.cast<Map<String, dynamic>>();
    }
    throw StateError(
      'Places Autocomplete: invalid response (predictions missing).',
    );
  }

  /// Local Carmona/Cavite bias first, then Philippines-wide autocomplete, then geocode.
  Future<({List<Map<String, dynamic>> predictions, bool widened})>
      searchPlaces(
    String input, {
    LatLng? near,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return (predictions: const <Map<String, dynamic>>[], widened: false);
    }
    final local = await _autocompleteRequest(trimmed, near: near, localBias: true);
    if (local.isNotEmpty) {
      return (predictions: local, widened: false);
    }
    final wide = await _autocompleteRequest(trimmed, near: near, localBias: false);
    if (wide.isNotEmpty) {
      return (predictions: wide, widened: true);
    }
    final geocoded = await forwardGeocode(trimmed);
    return (predictions: geocoded, widened: true);
  }

  Future<List<Map<String, dynamic>>> autocompletePlaces(
    String input, {
    LatLng? near,
  }) async {
    final result = await searchPlaces(input, near: near);
    return result.predictions;
  }

  Future<List<Map<String, dynamic>>> forwardGeocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {
        'address': trimmed,
        'components': 'country:PH',
        'key': googleMapsWebServicesApiKey,
      },
    );
    _ensureGoogleApiOk(response.data, 'Geocoding');
    final results = response.data?['results'];
    if (results is! List || results.isEmpty) return [];
    return results
        .cast<Map<String, dynamic>>()
        .map(
          (r) => {
            'place_id': r['place_id'],
            'description': r['formatted_address'] as String? ?? trimmed,
          },
        )
        .where((r) => r['place_id'] != null)
        .toList();
  }

  Future<({LatLng location, String address})> placeDetails(
    String placeId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry,formatted_address',
          'key': googleMapsWebServicesApiKey,
        },
      );
      _ensureGoogleApiOk(response.data, 'Place Details');
      final result = response.data?['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble() ?? 0;
      final lng = (loc?['lng'] as num?)?.toDouble() ?? 0;
      final address = result?['formatted_address'] as String? ?? '';
      return (location: LatLng(lat, lng), address: address);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> reverseGeocode(LatLng point) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${point.latitude},${point.longitude}',
          'key': googleMapsWebServicesApiKey,
        },
      );
      _ensureGoogleApiOk(response.data, 'Geocoding');
      final results = response.data?['results'];
      if (results is List && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        return first['formatted_address'] as String? ?? '';
      }
      return '';
    } catch (e) {
      rethrow;
    }
  }

  Future<({List<LatLng> points, double distanceMeters, int durationSeconds})>
      fetchDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'departure_time': 'now',
          'traffic_model': 'best_guess',
          'key': googleMapsWebServicesApiKey,
        },
      );
      _ensureGoogleApiOk(response.data, 'Directions');
      final routes = response.data?['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return (points: <LatLng>[], distanceMeters: 0.0, durationSeconds: 0);
      }
      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>? ?? [];
      var meters = 0.0;
      var durationSec = 0;
      for (final leg in legs) {
        final map = leg as Map<String, dynamic>;
        meters += ((map['distance'] as Map<String, dynamic>?)?['value'] as num?)
                ?.toDouble() ??
            0;
        final traffic = map['duration_in_traffic'] as Map<String, dynamic>?;
        final duration = traffic ?? map['duration'] as Map<String, dynamic>?;
        durationSec += (duration?['value'] as num?)?.toInt() ?? 0;
      }
      final overview = route['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String? ?? '';
      return (
        points: decodePolyline(encoded),
        distanceMeters: meters,
        durationSeconds: durationSec,
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _tripInsertRow({
    required String riderId,
    required String pickupAddress,
    required String dropoffAddress,
    required LatLng pickup,
    required LatLng dropoff,
    required double fare,
    double? distanceKm,
    String? distanceColumn,
  }) {
    final row = <String, dynamic>{
      'rider_id': riderId,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_lat': pickup.latitude,
      'pickup_lng': pickup.longitude,
      'dropoff_lat': dropoff.latitude,
      'dropoff_lng': dropoff.longitude,
      'status': 'requested',
      'fare': fare,
    };
    if (distanceKm != null && distanceColumn != null) {
      row[distanceColumn] = distanceKm;
    }
    return row;
  }

  bool _isMissingColumnError(Object e, String column) {
    final msg = e.toString();
    return msg.contains('PGRST204') && msg.contains(column);
  }

  Future<TripModel> _insertTripRow(Map<String, dynamic> row) async {
    final inserted = await _client.from('trips').insert(row).select().single();
    final trip = TripModel.fromJson(inserted);
    await _audit.log(
      action: 'trip.create',
      entityType: 'trips',
      entityId: trip.id,
      summary: 'Rider booked a trip',
      metadata: {
        'pickup': row['pickup_address'],
        'dropoff': row['dropoff_address'],
        'fare': row['fare'],
      },
    );
    return trip;
  }

  Future<TripModel> createTrip({
    required String riderId,
    required String pickupAddress,
    required String dropoffAddress,
    required LatLng pickup,
    required LatLng dropoff,
    required double fare,
    required double distanceKm,
  }) async {
    await _auth.ensureUserRowExists();

    final base = _tripInsertRow(
      riderId: riderId,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickup: pickup,
      dropoff: dropoff,
      fare: fare,
    );

    try {
      return await _insertTripRow(
        _tripInsertRow(
          riderId: riderId,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          pickup: pickup,
          dropoff: dropoff,
          fare: fare,
          distanceKm: distanceKm,
          distanceColumn: 'distance_km',
        ),
      );
    } catch (e) {
      if (_isMissingColumnError(e, 'distance_km')) {
        try {
          return await _insertTripRow(
            _tripInsertRow(
              riderId: riderId,
              pickupAddress: pickupAddress,
              dropoffAddress: dropoffAddress,
              pickup: pickup,
              dropoff: dropoff,
              fare: fare,
              distanceKm: distanceKm,
              distanceColumn: 'distance',
            ),
          );
        } catch (e2) {
          if (_isMissingColumnError(e2, 'distance')) {
            return await _insertTripRow(base);
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> cancelTrip(String tripId) async {
    try {
      await _client.from('trips').update({
        'status': 'cancelled',
      }).eq('id', tripId);
      await _audit.log(
        action: 'trip.cancel',
        entityType: 'trips',
        entityId: tripId,
        summary: 'Rider cancelled trip',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TripModel>> completedTripsForRider(String riderId) async {
    try {
      final rows = await _client
          .from('trips')
          .select()
          .eq('rider_id', riderId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<TripModel?> fetchTrip(String id) async {
    try {
      final row =
          await _client.from('trips').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return TripModel.fromJson(row);
    } catch (e) {
      rethrow;
    }
  }

  /// Rider's in-progress booking (requested, accepted, or ongoing).
  Future<TripModel?> fetchActiveTripForRider(String riderId) async {
    try {
      final row = await _client
          .from('trips')
          .select()
          .eq('rider_id', riderId)
          .inFilter('status', ['requested', 'accepted', 'ongoing'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return TripModel.fromJson(row);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitTripRating({
    required String tripId,
    required int rating,
    String? reviewText,
    List<String> complaintTags = const [],
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    if (rating < 1 || rating > 5) throw ArgumentError('Rating must be 1–5');

    final existing = await _client
        .from('trips')
        .select('id, status, rating')
        .eq('id', tripId)
        .eq('rider_id', uid)
        .maybeSingle();

    if (existing == null) {
      throw StateError('Trip not found or you are not the rider on this trip.');
    }
    if (existing['status'] != 'completed') {
      throw StateError(
        'Trip must be completed before rating (current status: ${existing['status']}).',
      );
    }

    final trimmedReview =
        reviewText?.trim().isEmpty == true ? null : reviewText?.trim();

    final fullPayload = <String, dynamic>{
      'rating': rating,
      'review_text': trimmedReview,
      'complaint_tags': complaintTags,
      'rating_submitted_at': DateTime.now().toUtc().toIso8601String(),
    };

    Map<String, dynamic>? saved;
    try {
      saved = await _applyRatingUpdate(
        tripId: tripId,
        riderId: uid,
        payload: fullPayload,
      );
    } catch (e) {
      if (_isMissingColumnError(e, 'rating') ||
          _isMissingColumnError(e, 'review_text') ||
          _isMissingColumnError(e, 'complaint_tags') ||
          _isMissingColumnError(e, 'rating_submitted_at')) {
        throw StateError(
          'Rating is not enabled in the database yet. '
          'Run fix_trip_ratings.sql in Supabase SQL Editor, then try again.',
        );
      }
      rethrow;
    }

    if (saved == null) {
      throw StateError('Rating was not saved. Please try again.');
    }

    await _audit.log(
      action: 'trip.rate',
      entityType: 'trips',
      entityId: tripId,
      summary: 'Rider rated trip ($rating★)',
      metadata: {
        'rating': rating,
        if (trimmedReview != null) 'review_text': trimmedReview,
        'complaint_tags': complaintTags,
      },
    );
  }

  Future<Map<String, dynamic>?> _applyRatingUpdate({
    required String tripId,
    required String riderId,
    required Map<String, dynamic> payload,
  }) async {
    final row = await _client
        .from('trips')
        .update(payload)
        .eq('id', tripId)
        .eq('rider_id', riderId)
        .eq('status', 'completed')
        .select('id, rating, review_text, complaint_tags, rating_submitted_at')
        .maybeSingle();
    return row;
  }

  Stream<List<Map<String, dynamic>>> tripStream(String tripId) {
    return _client.from('trips').stream(primaryKey: ['id']).eq('id', tripId);
  }
}
