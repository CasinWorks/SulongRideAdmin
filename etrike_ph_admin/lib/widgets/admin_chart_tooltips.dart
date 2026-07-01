import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Shared fl_chart tooltip styling — white text on the default dark tooltip bg.
abstract final class AdminChartTooltips {
  static const _textStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  static LineTouchData lineTouchData() => LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (s) => LineTooltipItem(
                  s.y.toInt().toString(),
                  _textStyle,
                ),
              )
              .toList(),
        ),
      );

  static BarTouchData barTouchData() => BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            rod.toY.toInt().toString(),
            _textStyle,
          ),
        ),
      );
}
