import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/message_model.dart';

class ChatDeliveryStatusLabel extends StatelessWidget {
  const ChatDeliveryStatusLabel({
    super.key,
    required this.status,
    required this.isMine,
  });

  final MessageDeliveryStatus status;
  final bool isMine;

  String get _label {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return 'Sending..';
      case MessageDeliveryStatus.sent:
      case MessageDeliveryStatus.delivered:
        return 'Sent....';
      case MessageDeliveryStatus.read:
        return 'Read...';
      case MessageDeliveryStatus.failed:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isMine || status == MessageDeliveryStatus.failed) {
      return const SizedBox.shrink();
    }

    final color = status == MessageDeliveryStatus.read
        ? const Color(0xFF4FC3F7)
        : AppColors.ecoCream.withValues(alpha: 0.65);

    return Text(
      _label,
      style: AppTextStyles.bodySecondary.copyWith(
        fontSize: 10,
        fontStyle: status == MessageDeliveryStatus.sending
            ? FontStyle.italic
            : FontStyle.normal,
        color: color,
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.isRiderBubble,
  });

  final MessageModel message;
  final String currentUserId;
  final bool isRiderBubble;

  @override
  Widget build(BuildContext context) {
    final isMine = message.senderId == currentUserId;
    final status = message.deliveryStatusFor(currentUserId);

    return Align(
      alignment: isRiderBubble ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isRiderBubble ? AppColors.ecoGreen : AppColors.forestMedium,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isRiderBubble ? 16 : 4),
            bottomRight: Radius.circular(isRiderBubble ? 4 : 16),
          ),
          border: isRiderBubble
              ? null
              : Border.all(color: AppColors.forestLight.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: AppTextStyles.body.copyWith(
                color: AppColors.ecoCream,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == MessageDeliveryStatus.failed)
                  Text(
                    'Failed to send',
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 9,
                      color: AppColors.error,
                    ),
                  ),
                if (status == MessageDeliveryStatus.failed) const SizedBox(width: 4),
                ChatDeliveryStatusLabel(status: status, isMine: isMine),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
