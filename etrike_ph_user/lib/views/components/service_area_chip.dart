import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/place_provider.dart';

class ServiceAreaChip extends ConsumerWidget {
  const ServiceAreaChip({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlaceProvider);
    final places = ref.watch(activePlacesProvider).asData?.value ?? [selected];

    return Material(
      color: AppColors.forestMedium.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showServiceAreaPicker(context, ref),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_city_outlined, size: 18, color: AppColors.ecoGreenLight),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  compact ? selected.name : selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontSize: compact ? 13 : 14),
                ),
              ),
              if (places.length > 1) ...[
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 18, color: AppColors.ecoCreamDark),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showServiceAreaPicker(BuildContext context, WidgetRef ref) async {
  final places = ref.read(activePlacesProvider).asData?.value ??
      [ref.read(selectedPlaceProvider)];
  final selected = ref.read(selectedPlaceProvider);

  await showModalBottomSheet<void>(
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
              Text('Where are you booking?', style: AppTextStyles.headingSm),
              const SizedBox(height: 6),
              Text(
                'Sulong Ride only operates in listed villages. Pick yours so the map and e-trikes stay in that area.',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              for (final place in places)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    place.id == selected.id ? Icons.check_circle : Icons.place_outlined,
                    color: AppColors.ecoGreenLight,
                  ),
                  title: Text(place.name, style: AppTextStyles.body),
                  subtitle: Text(
                    place.displayName ?? place.name,
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  onTap: () {
                    ref.read(selectedPlaceProvider.notifier).select(place);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
