import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// iOS-style switch — tap or slide right for on, left for off.
class EcoToggle extends StatefulWidget {
  const EcoToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<EcoToggle> createState() => _EcoToggleState();
}

class _EcoToggleState extends State<EcoToggle> {
  static const _trackWidth = 51.0;
  static const _trackHeight = 31.0;
  static const _thumbSize = 27.0;
  static const _padding = 2.0;

  double _dragProgress = 0;
  bool _dragging = false;

  double get _travel => _trackWidth - _thumbSize - _padding * 2;

  @override
  void didUpdateWidget(covariant EcoToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) {
      _dragProgress = widget.value ? 1 : 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _dragProgress = widget.value ? 1 : 0;
  }

  void _commitDrag() {
    final enable = _dragProgress >= 0.5;
    setState(() {
      _dragging = false;
      _dragProgress = enable ? 1 : 0;
    });
    if (enable != widget.value) {
      widget.onChanged(enable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbLeft = _padding + _dragProgress * _travel;
    final trackColor = Color.lerp(
      AppColors.forestLight,
      AppColors.ecoGreen,
      _dragProgress,
    )!;

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      onHorizontalDragStart: (_) {
        setState(() => _dragging = true);
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragProgress =
              (_dragProgress + details.delta.dx / _travel).clamp(0.0, 1.0);
        });
      },
      onHorizontalDragEnd: (_) => _commitDrag(),
      onHorizontalDragCancel: _commitDrag,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: _trackWidth,
        height: _trackHeight,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(_trackHeight / 2),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: thumbLeft,
              top: _padding,
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: AppColors.ecoCream,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
