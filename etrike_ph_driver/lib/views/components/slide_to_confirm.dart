import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Slide the thumb to the right to confirm an irreversible action.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.confirmedLabel = 'Confirmed',
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;
  final String confirmedLabel;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _drag = 0;
  bool _confirmed = false;

  static const _trackHeight = 56.0;
  static const _thumbSize = 48.0;
  static const _padding = 4.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - _thumbSize - _padding * 2)
            .clamp(0.0, double.infinity);
        final progress = maxDrag <= 0 ? 0.0 : (_drag / maxDrag).clamp(0.0, 1.0);

        return Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: _confirmed ? AppColors.accent.withValues(alpha: 0.15) : AppColors.forestLight,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              border: Border.all(
                color: _confirmed
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _thumbSize + 12),
                    child: Center(
                      child: Text(
                        _confirmed ? widget.confirmedLabel : widget.label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: _confirmed ? AppColors.accent : AppColors.ecoCream.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_confirmed && progress > 0.05)
                  Positioned(
                    left: _padding,
                    top: _padding,
                    bottom: _padding,
                    width: _drag + _thumbSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular((_trackHeight - _padding * 2) / 2),
                      ),
                    ),
                  ),
                Positioned(
                  left: _padding + _drag,
                  top: _padding,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.enabled && !_confirmed
                        ? (details) {
                            setState(() {
                              _drag = (_drag + details.delta.dx).clamp(0.0, maxDrag);
                            });
                          }
                        : null,
                    onHorizontalDragEnd: widget.enabled && !_confirmed
                        ? (_) {
                            if (_drag >= maxDrag * 0.88) {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _drag = maxDrag;
                                _confirmed = true;
                              });
                              widget.onConfirmed();
                            } else {
                              setState(() => _drag = 0);
                            }
                          }
                        : null,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: _confirmed ? AppColors.accent : AppColors.ecoCream,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _confirmed ? Icons.check_rounded : Icons.chevron_right_rounded,
                        color: _confirmed ? AppColors.ecoCream : AppColors.forestLight,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
