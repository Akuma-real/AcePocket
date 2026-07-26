import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/downsample.dart';
import '../../../core/widgets/section_card.dart';
import 'formatters.dart';

/// 历史监控图表的一条数据序列。
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.values,
    required this.color,
  });

  final String name;
  final List<double> values;
  final Color color;
}

/// 历史监控折线图卡片：多序列 + 图例 + 触摸提示 + 时间轴。
class MonitorChartCard extends StatelessWidget {
  const MonitorChartCard({
    super.key,
    required this.title,
    required this.times,
    required this.series,
    required this.valueFormatter,
    this.trailing,
    this.subtitle,
    this.minY,
    this.maxY,
    this.height = 200,
  });

  final String title;

  /// 时间标签（与序列一一对应，格式 `yyyy-MM-dd HH:mm:ss`）。
  final List<String> times;

  final List<ChartSeries> series;

  /// 数值格式化（用于纵轴刻度与提示气泡）。
  final String Function(double value) valueFormatter;

  /// 标题行尾部组件（如网卡下拉选择）。
  final Widget? trailing;

  /// 标题下方补充说明（如内存总量）。
  final String? subtitle;

  final double? minY;
  final double? maxY;
  final double height;

  /// 抽样后交给 fl_chart 绘制的目标点数上限。
  ///
  /// 30 天 × 分钟级采样约 4.3 万点/曲线，全量绘制会导致滑动与 tooltip
  /// 明显掉帧；超过该值时先做 LTTB 抽样（并强制保留各序列全局极值点，
  /// 见 [downsampleIndexes]），实际点数最多为该值 + 2 × 序列数。
  static const int _maxPoints = 300;

  int get _length {
    var length = times.length;
    for (final s in series) {
      length = math.min(length, s.values.length);
    }
    return length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final withDate = _spansMultipleDays;

    // 数据点过多时先抽样再绘制，峰值（各序列全局最值）保证保留。
    var times = this.times;
    var series = this.series;
    String? sampleNote;
    final rawLength = _length;
    if (rawLength > _maxPoints) {
      final indexes = downsampleIndexes(
        length: rawLength,
        seriesValues: [for (final s in series) s.values],
        threshold: _maxPoints,
      );
      times = [for (final i in indexes) times[i]];
      series = [
        for (final s in series)
          ChartSeries(
            name: s.name,
            values: [for (final i in indexes) s.values[i]],
            color: s.color,
          ),
      ];
      sampleNote = '已抽样显示，共 ${indexes.length} 个采样点';
    }
    final length = math.min(rawLength, times.length);

    final subtitleText = [
      if (subtitle != null) subtitle!,
      if (sampleNote != null) sampleNote,
    ].join(' · ');

    if (length < 2) {
      return SectionCard(
        title: title,
        trailing: trailing,
        child: SizedBox(
          height: 96,
          child: Center(
            child: Text(
              '该时间段数据点不足，无法绘制图表',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    var bottom = minY ?? double.infinity;
    var top = maxY ?? double.negativeInfinity;
    if (minY == null || maxY == null) {
      for (final s in series) {
        for (var i = 0; i < length; i++) {
          final v = s.values[i];
          if (minY == null && v < bottom) bottom = v;
          if (maxY == null && v > top) top = v;
        }
      }
    }
    if (!bottom.isFinite) bottom = 0;
    if (!top.isFinite) top = 1;
    if (top - bottom < 1e-9) top = bottom + (bottom.abs() < 1e-9 ? 1 : bottom.abs() * 0.2);
    final padding = (top - bottom) * 0.1;
    if (maxY == null) top += padding;
    if (minY == null) bottom = math.max(0, bottom - padding);

    final labelInterval = math.max(1, (length / 4).ceil()).toDouble();

    return SectionCard(
      title: title,
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitleText.isNotEmpty) ...[
            Text(
              subtitleText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final s in series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 3,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (length - 1).toDouble(),
                minY: bottom,
                maxY: top,
                clipData: FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (top - bottom) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: (top - bottom) / 4,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        child: Text(
                          valueFormatter(value),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: labelInterval,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            formatChartTime(times[index], withDate: withDate),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        theme.colorScheme.inverseSurface.withValues(alpha: 0.92),
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      final items = <LineTooltipItem>[];
                      for (var i = 0; i < touchedSpots.length; i++) {
                        final spot = touchedSpots[i];
                        final name = spot.barIndex < series.length
                            ? series[spot.barIndex].name
                            : '';
                        final color = spot.barIndex < series.length
                            ? series[spot.barIndex].color
                            : theme.colorScheme.onInverseSurface;
                        final index = spot.spotIndex;
                        final prefix = i == 0 && index < times.length
                            ? '${formatTooltipTime(times[index])}\n'
                            : '';
                        items.add(
                          LineTooltipItem(
                            '$prefix$name  ${valueFormatter(spot.y)}',
                            TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return items;
                    },
                  ),
                ),
                lineBarsData: [
                  for (final s in series)
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < length; i++)
                          FlSpot(i.toDouble(), s.values[i]),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.2,
                      preventCurveOverShooting: true,
                      color: s.color,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: series.length == 1,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            s.color.withValues(alpha: 0.24),
                            s.color.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数据是否跨天（决定时间轴标签是否带日期）。
  bool get _spansMultipleDays {
    if (times.length < 2) return false;
    final first = parseMonitorTime(times.first);
    final last = parseMonitorTime(times.last);
    if (first == null || last == null) return false;
    return first.year != last.year ||
        first.month != last.month ||
        first.day != last.day;
  }
}
