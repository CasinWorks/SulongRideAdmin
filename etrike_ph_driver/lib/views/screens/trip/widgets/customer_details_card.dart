import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_decorations.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../models/rider_contact.dart';

class CustomerDetailsCard extends StatelessWidget {
  const CustomerDetailsCard({
    super.key,
    required this.contact,
    this.compact = false,
    this.onChat,
  });

  final RiderContact contact;
  final bool compact;
  final VoidCallback? onChat;

  Future<void> _call(BuildContext context) async {
    final phone = contact.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This passenger has no phone on file.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not call $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = contact.profilePhotoUrl;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: AppDecorations.ecoCard,
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 20 : 24,
            backgroundColor: AppColors.forestLight,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    contact.initial,
                    style: AppTextStyles.headingSm.copyWith(
                      color: AppColors.ecoGreenLight,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Passenger', style: AppTextStyles.label),
                Text(
                  contact.fullName,
                  style: AppTextStyles.headingSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  contact.phone ?? 'No phone on file',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          _CircleBtn(
            icon: Icons.phone_outlined,
            onTap: contact.phone == null ? null : () => _call(context),
          ),
          if (onChat != null) ...[
            const SizedBox(width: 8),
            _CircleBtn(icon: Icons.chat_bubble_outline, onTap: onChat),
          ],
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.textSecondary : AppColors.ecoGreenLight,
          ),
        ),
      ),
    );
  }
}
