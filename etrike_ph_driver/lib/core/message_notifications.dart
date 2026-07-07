import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/trip_provider.dart';
import 'driver_local_store.dart';
import 'local_notifications_service.dart';
import 'trip_live_activity_service.dart';

/// Watches the active trip's chat stream and fires local notifications for new
/// messages from the other party when chat is not open.
final messageNotificationsProvider = Provider<void>((ref) {
  final coordinator = _MessageNotificationCoordinator(
    ref,
    activeTripProvider: driverActiveTripProvider,
    pushEnabled: DriverLocalStore.pushNotifications,
    peerLabel: 'Rider',
  );
  ref.onDispose(coordinator.dispose);
});

class _MessageNotificationCoordinator {
  _MessageNotificationCoordinator(
    this.ref, {
    required this.activeTripProvider,
    required this.pushEnabled,
    required this.peerLabel,
  }) {
    ref.listen<AsyncValue<dynamic>>(activeTripProvider, (previous, next) {
      final trip = next.asData?.value as TripModel?;
      _bindTrip(trip);
    }, fireImmediately: true);
  }

  final Ref ref;
  final ProviderListenable<AsyncValue<dynamic>> activeTripProvider;
  final Future<bool> Function() pushEnabled;
  final String peerLabel;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  TripModel? _trip;
  final Set<String> _notifiedIds = {};
  List<String> _knownIds = [];
  bool _seeded = false;

  void _bindTrip(TripModel? trip) {
    final tripId = trip?.id;
    if (_trip?.id == tripId) return;
    _sub?.cancel();
    _trip = trip;
    _notifiedIds.clear();
    _knownIds = [];
    _seeded = false;

    if (tripId == null) {
      unawaited(DriverTripLiveActivityService.end());
      return;
    }

    final repo = ref.read(chatRepositoryProvider);
    _sub = repo.messagesStream(tripId).listen((rows) {
      unawaited(_onMessages(repo.mapRows(rows), tripId));
    });
  }

  Future<void> _onMessages(List<MessageModel> messages, String tripId) async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;

    if (!_seeded) {
      _knownIds = messages.map((m) => m.id).toList();
      _seeded = true;
      return;
    }

    final chatVisible = ref.read(tripChatProvider(tripId)).chatVisible;
    if (chatVisible) {
      _knownIds = messages.map((m) => m.id).toList();
      return;
    }

    if (!await pushEnabled()) return;

    for (final message in messages) {
      if (message.senderId == uid) continue;
      if (_knownIds.contains(message.id) || _notifiedIds.contains(message.id)) {
        continue;
      }
      _notifiedIds.add(message.id);
      final preview = message.message.length > 100
          ? '${message.message.substring(0, 100)}…'
          : message.message;
      await LocalNotificationsService.showChatMessage(
        notificationId: message.id.hashCode,
        title: peerLabel,
        body: preview,
        tripId: tripId,
      );
      final trip = _trip;
      if (trip != null &&
          (trip.status == 'accepted' || trip.status == 'ongoing')) {
        await DriverTripLiveActivityService.showChatPreview(
          trip: trip,
          preview: preview,
        );
      }
    }
    _knownIds = messages.map((m) => m.id).toList();
  }

  void dispose() => _sub?.cancel();
}
