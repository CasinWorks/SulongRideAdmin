import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';
import 'audit_repository.dart';

class ChatRepository {
  ChatRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  Future<MessageModel> sendMessage({
    required String tripId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final inserted = await _client.from('messages').insert({
      'trip_id': tripId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': text,
    }).select().single();
    await _audit.log(
      action: 'chat.send',
      entityType: 'trips',
      entityId: tripId,
      summary: 'Rider sent chat message',
      metadata: {'sender_role': senderRole},
    );
    return MessageModel.fromJson(inserted);
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String tripId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId);
  }

  Future<List<MessageModel>> fetchMessages(String tripId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('trip_id', tripId)
        .order('created_at');
    return (rows as List<dynamic>)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markDelivered(String messageId) async {
    await _client.from('messages').update({
      'delivered_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> markRead(String messageId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('messages').update({
      'delivered_at': now,
      'read_at': now,
    }).eq('id', messageId);
  }

  List<MessageModel> mapRows(List<Map<String, dynamic>> rows) {
    final sorted = [...rows]
      ..sort(
        (a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
    return sorted.map(MessageModel.fromJson).toList();
  }
}
