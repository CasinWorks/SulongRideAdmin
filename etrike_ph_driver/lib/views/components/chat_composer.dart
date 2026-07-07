import 'package:flutter/material.dart';

import '../../core/chat_error_message.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/message_model.dart';
import 'chat_message_bubble.dart';
import 'primary_button.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    this.presets = const [],
    this.hintText = 'Message rider',
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
        'Chat opens once you accept the booking.',
        style: AppTextStyles.bodySecondary,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (presets.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 10)),
                        onPressed: () => onSend(p),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (presets.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) => onSend(v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 52,
              child: PrimaryButton(
                label: 'Send',
                onPressed: () => onSend(controller.text),
              ),
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
    this.error,
    this.loading = false,
  });

  final List<MessageModel> messages;
  final String? currentUserId;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
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
        child: Text('No messages yet.', style: AppTextStyles.bodySecondary),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final isDriver = m.senderRole == 'driver';
        return ChatMessageBubble(
          message: m,
          currentUserId: currentUserId ?? '',
          isDriverBubble: isDriver,
        );
      },
    );
  }
}
