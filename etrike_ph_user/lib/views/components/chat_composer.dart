import 'package:flutter/material.dart';

import '../../core/chat_error_message.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/message_model.dart';
import 'chat_message_bubble.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.presets,
    this.hintText = 'Type a message…',
  });

  final TextEditingController controller;
  final bool enabled;
  final Future<void> Function(String text) onSend;
  final List<String> presets;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Text(
        'Chat opens when the driver accepts your booking.',
        style: AppTextStyles.bodySecondary,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 10)),
                      backgroundColor: AppColors.forestMedium,
                      side: BorderSide(
                        color: AppColors.forestLight.withValues(alpha: 0.4),
                      ),
                      onPressed: () => onSend(p),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: AppTextStyles.bodySecondary,
                  filled: true,
                  fillColor: AppColors.forestMedium,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) => onSend(v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.ecoGreen),
              onPressed: () => onSend(controller.text),
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.isRiderPerspective,
    this.error,
    this.loading = false,
  });

  final List<MessageModel> messages;
  final String? currentUserId;
  final bool isRiderPerspective;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.ecoGreen),
      );
    }
    if (error != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            formatChatSetupError(error!),
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello!',
          style: AppTextStyles.bodySecondary,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final isRider = m.senderRole == 'rider';
        return ChatMessageBubble(
          message: m,
          currentUserId: currentUserId ?? '',
          isRiderBubble: isRiderPerspective ? isRider : !isRider,
        );
      },
    );
  }
}
