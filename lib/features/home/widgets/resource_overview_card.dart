import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';
import 'formatters.dart';
import 'mini_chart.dart';

/// 实时资源总览：CPU 与内存的环形仪表 + 迷你趋势图。
class ResourceOverviewCard extends StatelessWidget {
  const ResourceOverviewCard({super.key, required this.state, this.updatedAt});

  final RealtimeState state;

  /// 最近一次采样时间（展示在标题右侧）。
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = state.info;
    final memPercent = info.mem.total > 0
        ? info.mem.used / info.mem.total * 100
        : info.mem.usedPercent;

    return SectionCard(
      title: '实时负载',
      trailing: Text(
        updatedAt == null ? '' : '更新于 ${formatChartTimeOfDay(updatedAt!)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Gauge(
                  label: 'CPU',
                  percent: info.percent,
                  caption: info.cores > 0 ? '${info.cores} 核' : '—',
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _Gauge(
                  label: '内存',
                  percent: memPercent,
                  caption:
                      '${formatBytes(info.mem.used)} / ${formatBytes(info.mem.total)}',
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Trend(
                  title: 'CPU 趋势',
                  values: state.cpuHistory,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Trend(
                  title: '内存趋势',
                  values: state.memHistory,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          if (info.swap.total > 0) ...[
            const SizedBox(height: 4),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.swap_horiz,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'SWAP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${formatBytes(info.swap.used)} / ${formatBytes(info.swap.total)}'
                  '（${formatPercent(info.swap.usedPercent)}）',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 首页仪表用的时分格式（避免在 formatters 中再暴露一个 DateFormat 实例）。
///
/// `.hour` / `.minute` 取的是实例自身时区下的字段，UTC 实例会少算时区偏移，
/// 因此先 `.toLocal()`（对已是本地时区的实例是空操作）。
String formatChartTimeOfDay(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.percent,
    required this.caption,
    required this.color,
  });

  final String label;
  final double percent;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = percent.isFinite ? percent.clamp(0.0, 100.0) : 0.0;
    final tint = value >= 90 ? theme.colorScheme.error : color;
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value / 100,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(tint),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  Text(
                    '%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        MiniChart(values: values, color: color, minY: 0, maxY: 100, height: 46),
      ],
    );
  }
}
