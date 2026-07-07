import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../repositories/chat_repository.dart';
import 'auth_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);

class TripChatState {
  const TripChatState({
    this.serverMessages = const [],
    this.pendingMessages = const [],
    this.error,
    this.loading = true,
    this.chatVisible = false,
  });

  final List<MessageModel> serverMessages;
  final List<MessageModel> pendingMessages;
  final String? error;
  final bool loading;
  final bool chatVisible;

  List<MessageModel> mergedMessages(String currentUserId) {
    final pending = pendingMessages.where((p) {
      if (p.id.startsWith('pending-')) {
        return !serverMessages.any(
          (s) =>
              s.senderId == p.senderId &&
              s.message == p.message &&
              s.createdAt.difference(p.createdAt).inSeconds.abs() < 45,
        );
      }
      return !serverMessages.any((s) => s.id == p.id);
    }).toList();
    final all = [...serverMessages, ...pending]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  TripChatState copyWith({
    List<MessageModel>? serverMessages,
    List<MessageModel>? pendingMessages,
    String? error,
    bool? loading,
    bool? chatVisible,
  }) {
    return TripChatState(
      serverMessages: serverMessages ?? this.serverMessages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      error: error,
      loading: loading ?? this.loading,
      chatVisible: chatVisible ?? this.chatVisible,
    );
  }
}

class TripChatNotifier extends StateNotifier<TripChatState> {
  TripChatNotifier(this.ref, this.tripId) : super(const TripChatState()) {
    _init();
  }

  final Ref ref;
  final String tripId;
  StreamSubscription<List<MessageModel>>? _sub;
  Timer? _pollTimer;
  bool _refreshing = false;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  String? get _userId => ref.read(supabaseClientProvider).auth.currentUser?.id;

  Future<void> _init() async {
    try {
      await _refreshMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }

    _sub = _watchMessages().listen(
      (messages) async {
        state = state.copyWith(serverMessages: messages, error: null, loading: false);
        _prunePending(messages);
        await _syncReceipts();
      },
      onError: (e) => state = state.copyWith(error: e.toString(), loading: false),
    );

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncReceipts());
  }

  Stream<List<MessageModel>> _watchMessages() async* {
    try {
      await for (final rows in _repo.messagesStream(tripId).timeout(const Duration(seconds: 10))) {
        yield _repo.mapRows(rows);
      }
    } on TimeoutException {
      // poll-only fallback
    } catch (_) {}
  }

  Future<void> _refreshMessages() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final messages = await _repo.fetchMessages(tripId);
      state = state.copyWith(serverMessages: messages, loading: false, error: null);
      _prunePending(messages);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _syncReceipts() async {
    try {
      await _refreshMessages();
      final messages = state.serverMessages;
      var touched = false;

      touched = await _ackDelivered(messages) || touched;
      if (state.chatVisible) {
        touched = await _ackRead(messages) || touched;
      }

      if (touched) {
        await _refreshMessages();
      }
    } catch (_) {}
  }

  Future<bool> _ackDelivered(List<MessageModel> messages) async {
    final uid = _userId;
    if (uid == null) return false;
    var touched = false;
    for (final m in messages) {
      if (m.senderId == uid || m.deliveredAt != null) continue;
      try {
        await _repo.markDelivered(m.id);
        touched = true;
      } catch (_) {}
    }
    return touched;
  }

  Future<bool> _ackRead(List<MessageModel> messages) async {
    final uid = _userId;
    if (uid == null) return false;
    var touched = false;
    for (final m in messages) {
      if (m.senderId == uid || m.readAt != null) continue;
      try {
        await _repo.markRead(m.id);
        touched = true;
      } catch (_) {}
    }
    return touched;
  }

  void setChatVisible(bool visible) {
    if (state.chatVisible == visible) return;
    state = state.copyWith(chatVisible: visible);
    if (visible) {
      unawaited(_syncReceipts());
    }
  }

  Future<void> markInboxRead() async {
    setChatVisible(true);
  }

  void _prunePending(List<MessageModel> server) {
    if (state.pendingMessages.isEmpty) return;
    final next = state.pendingMessages.where((p) {
      return !server.any(
        (s) =>
            s.senderId == p.senderId &&
            s.message == p.message &&
            s.createdAt.difference(p.createdAt).inSeconds.abs() < 45,
      );
    }).toList();
    if (next.length != state.pendingMessages.length) {
      state = state.copyWith(pendingMessages: next);
    }
  }

  Future<void> send({
    required String text,
    required String senderRole,
  }) async {
    final trimmed = text.trim();
    final uid = _userId;
    if (trimmed.isEmpty || uid == null) return;

    final clientId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = MessageModel.optimistic(
      clientId: clientId,
      tripId: tripId,
      senderId: uid,
      senderRole: senderRole,
      message: trimmed,
    );
    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, optimistic],
    );

    try {
      final saved = await _repo.sendMessage(
        tripId: tripId,
        senderId: uid,
        senderRole: senderRole,
        text: trimmed,
      );
      state = state.copyWith(
        pendingMessages: state.pendingMessages.where((p) => p.id != clientId).toList(),
        serverMessages: [...state.serverMessages, saved]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );
      await _refreshMessages();
    } catch (e) {
      state = state.copyWith(
        pendingMessages: state.pendingMessages
            .map(
              (p) => p.id == clientId
                  ? p.copyWith(localStatus: MessageDeliveryStatus.failed)
                  : p,
            )
            .toList(),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

final tripChatProvider =
    StateNotifierProvider.family<TripChatNotifier, TripChatState, String>(
  (ref, tripId) => TripChatNotifier(ref, tripId),
);

final tripMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, tripId) async* {
  final repo = ref.watch(chatRepositoryProvider);
  await for (final rows in repo.messagesStream(tripId)) {
    yield repo.mapRows(rows);
  }
});
