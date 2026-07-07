import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_decorations.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/trip_rating.dart';
import '../components/primary_button.dart';

/// Star rating + tags + optional comment — used after a ride and in trip history.
class TripRatingPanel extends StatelessWidget {
  const TripRatingPanel({
    super.key,
    required this.stars,
    required this.tags,
    required this.maxTags,
    required this.reviewCtrl,
    required this.onStar,
    required this.onTag,
    required this.onSubmit,
    this.title = 'Rate your driver',
    this.submitLabel = 'Submit rating',
    this.submitting = false,
    this.secondaryAction,
    this.secondaryLabel,
  });

  final int stars;
  final Set<String> tags;
  final int maxTags;
  final TextEditingController reviewCtrl;
  final ValueChanged<int> onStar;
  final ValueChanged<String> onTag;
  final VoidCallback? onSubmit;
  final String title;
  final String submitLabel;
  final bool submitting;
  final VoidCallback? secondaryAction;
  final String? secondaryLabel;

  bool get _isComplaintMode => stars <= 3;
  List<String> get _activeTags =>
      _isComplaintMode ? tripComplaintTags : tripPositiveTags;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.ecoCard.copyWith(
        border: Border.all(color: AppColors.ecoGreen.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.headingSm, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            _isComplaintMode
                ? 'Tell us what went wrong (optional tags, max $maxTags)'
                : 'What went well? (optional tags)',
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              return IconButton(
                onPressed: () => onStar(n),
                icon: Icon(
                  Icons.star,
                  size: 32,
                  color: n <= stars ? AppColors.amber : AppColors.forestLight,
                ),
              );
            }),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _activeTags.map((tag) {
              final selected = tags.contains(tag);
              return FilterChip(
                label: Text(tag, style: const TextStyle(fontSize: 10)),
                selected: selected,
                onSelected: (_) => onTag(tag),
                selectedColor: AppColors.ecoGreen,
                backgroundColor: AppColors.forestDark,
                labelStyle: TextStyle(
                  color: selected ? AppColors.ecoCream : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reviewCtrl,
            maxLines: 2,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Optional comment…',
              hintStyle: AppTextStyles.bodySecondary,
              filled: true,
              fillColor: AppColors.forestDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: submitting ? 'Saving…' : submitLabel,
            onPressed: submitting ? null : onSubmit,
          ),
          if (secondaryAction != null && secondaryLabel != null) ...[
            const SizedBox(height: 10),
            PrimaryButton(
              label: secondaryLabel!,
              useAccent: false,
              onPressed: secondaryAction,
            ),
          ],
        ],
      ),
    );
  }
}
