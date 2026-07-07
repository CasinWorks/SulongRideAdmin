import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_model.dart';
import '../utils/trip_rating_enrichment.dart';
import 'audit_repository.dart';

class TripRepository {
  TripRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  Future<FareConfig> fetchActiveFareConfig() async {
    try {
      final data = await _client
          .from('effective_fare_config')
          .select()
          .maybeSingle();
      if (data == null) {
        throw StateError('No effective fare row found.');
      }
      return FareConfig.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Open ride requests (`status = requested`, no driver yet).
  /// Realtime: subscribe without `.eq` — server allows only one stream filter;
  /// filter [status] and [driver_id] in the provider.
  Stream<List<Map<String, dynamic>>> requestedTripsStream() {
    return _client.from('trips').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> fetchOpenRequestedTrips() async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('status', 'requested');
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((row) => row['driver_id'] == null)
        .toList();
  }

  Stream<List<Map<String, dynamic>>> tripStream(String tripId) {
    return _client.from('trips').stream(primaryKey: ['id']).eq('id', tripId);
  }

  Future<void> acceptTrip({
    required String tripId,
    required String driverId,
  }) async {
    try {
      await _client.from('trips').update({
        'driver_id': driverId,
        'status': 'accepted',
      }).eq('id', tripId).eq('status', 'requested');
      unawaited(_audit.log(
        action: 'trip.accept',
        entityType: 'trips',
        entityId: tripId,
        summary: 'Driver accepted trip',
      ));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    try {
      await _client.from('trips').update({
        'status': status,
      }).eq('id', tripId);
      unawaited(_audit.log(
        action: 'trip.status_update',
        entityType: 'trips',
        entityId: tripId,
        summary: 'Trip status changed to $status',
        metadata: {'status': status},
      ));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> confirmCashPayment(String tripId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client.from('trips').update({
        'cash_payment_confirmed_at': now,
      }).eq('id', tripId);
    } catch (e) {
      final message = e.toString();
      if (message.contains('cash_payment_confirmed_at') &&
          (message.contains('PGRST204') || message.contains('schema cache'))) {
        return;
      }
      rethrow;
    }
    unawaited(_audit.log(
      action: 'trip.cash_payment_confirmed',
      entityType: 'trips',
      entityId: tripId,
      summary: 'Driver confirmed cash payment received',
    ));
  }

  Future<void> completeTrip(String tripId) async {
    try {
      await _client.from('trips').update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', tripId);
      unawaited(_audit.log(
        action: 'trip.complete',
        entityType: 'trips',
        entityId: tripId,
        summary: 'Driver completed trip',
      ));
    } catch (e) {
      final message = e.toString();
      if (message.contains('completed_at') &&
          (message.contains('PGRST204') || message.contains('schema cache'))) {
        await _client.from('trips').update({
          'status': 'completed',
        }).eq('id', tripId);
        unawaited(_audit.log(
          action: 'trip.complete',
          entityType: 'trips',
          entityId: tripId,
          summary: 'Driver completed trip',
        ));
        return;
      }
      rethrow;
    }
  }

  Future<TripModel?> fetchActiveTripForDriver(String driverId) async {
    try {
      final row = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', ['accepted', 'ongoing'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return TripModel.fromJson(row);
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

  Future<List<TripModel>> completedTripsForDriver(String driverId) async {
    try {
      final rows = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);
      final trips = (rows as List<dynamic>)
          .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final audit = await fetchAuditRatingsByTripId(_client);
      return enrichTripsWithAuditRatings(trips, audit);
    } catch (e) {
      rethrow;
    }
  }
}
