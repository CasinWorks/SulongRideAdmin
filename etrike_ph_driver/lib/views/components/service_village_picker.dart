import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/place_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/place_provider.dart';

Future<void> showServiceVillagePicker(BuildContext context, WidgetRef ref) async {
  final places = await ref.read(activePlacesProvider.future);
  if (!context.mounted) return;
  if (places.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No service villages yet. Ask your operator to add one, or run fix_place_malagasang_1b.sql.',
        ),
      ),
    );
    return;
  }

  final currentId = ref.read(driverProfileProvider).asData?.value?.placeId;
  final selected = await showModalBottomSheet<PlaceModel>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your service village', style: AppTextStyles.headingSm),
              const SizedBox(height: 6),
              Text(
                'Pick where you and your assigned e-trike will take bookings. Only riders in that village will see you.',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              for (final place in places)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    place.id == currentId ? Icons.check_circle : Icons.place_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text(place.name, style: AppTextStyles.body),
                  subtitle: Text(place.label, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
                  onTap: () => Navigator.of(ctx).pop(place),
                ),
            ],
          ),
        ),
      );
    },
  );

  if (selected == null || selected.id == currentId) return;
  try {
    await ref.read(authRepositoryProvider).updateOwnServicePlace(selected.id);
    ref.invalidate(driverProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now serving ${selected.name}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
