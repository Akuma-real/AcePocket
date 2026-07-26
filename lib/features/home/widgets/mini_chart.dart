import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 迷你趋势图（sparkline）：无坐标轴、无交互，用于首页实时指标卡片。
class MiniChart extends StatelessWidget {
  const MiniChart({
    super.key,
    required this.values,
    this.color,
    this.height = 48,
    this.minY,
    this.maxY,
    this.placeholder = '采集中…',
  });

  /// 数据序列（按时间先后排列）。
  final List<double> values;

  /// 线条颜色，默认取主题 primary。
  final Color? color;

  final double height;

  /// 纵轴下限 / 上限；为 null 时按数据自适应。
  final double? minY;
  final double? maxY;

  /// 数据点不足两个时展示的提示文字。
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = color ?? theme.colorScheme.primary;

    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            placeholder,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    var bottom = minY ?? values.reduce(math.min);
    var top = maxY ?? values.reduce(math.max);
    if (top - bottom < 1e-9) {
      // 全部数据相同（如速率恒为 0）时给一个可视高度，避免图表塌缩。
      top = bottom + (bottom.abs() < 1e-9 ? 1 : bottom.abs() * 0.2);
    }
    final padding = (top - bottom) * 0.12;
    if (maxY == null) top += padding;
    if (minY == null) bottom = math.max(0, bottom - padding);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: bottom,
          maxY: top,
          clipData: FlClipData.all(),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: lineColor,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.28),
                    lineColor.withValues(alpha: 0.02),
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
