import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/message_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../components/chat_composer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripChatProvider(widget.tripId).notifier).setChatVisible(true);
    });
  }

  @override
  void dispose() {
    ref.read(tripChatProvider(widget.tripId).notifier).setChatVisible(false);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    try {
      await ref.read(tripChatProvider(widget.tripId).notifier).send(
            text: text,
            senderRole: 'rider',
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripRealtimeProvider(widget.tripId));
    final chatState = ref.watch(tripChatProvider(widget.tripId));
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final messages = chatState.mergedMessages(uid ?? '');

    return tripAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trip not found')),
          );
        }

        final chatOpen = tripChatIsOpen(trip.status);

        return Scaffold(
          appBar: AppBar(
            title: Text('Chat', style: AppTextStyles.headingSm),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: ChatMessageList(
                  messages: messages,
                  currentUserId: uid,
                  isRiderPerspective: true,
                  loading: chatState.loading,
                  error: chatState.error,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ChatComposer(
                  controller: _controller,
                  enabled: chatOpen,
                  onSend: _send,
                  presets: const [
                    'Malapit na ako!',
                    'Sandali lang po.',
                    'Salamat!',
                  ],
                  hintText: 'Message your driver',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
