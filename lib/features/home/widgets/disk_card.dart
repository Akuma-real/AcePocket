import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';
import 'formatters.dart';
import 'info_row.dart';
import 'mini_chart.dart';

/// 磁盘卡片：读写速率趋势 + 各分区使用率。
class DiskCard extends StatelessWidget {
  const DiskCard({super.key, required this.state});

  final RealtimeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usages = state.info.diskUsage;

    return SectionCard(
      title: '磁盘',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _IoBlock(
                  icon: Icons.arrow_downward_rounded,
                  label: '读取',
                  rate: state.diskReadRate,
                  total: state.info.totalReadBytes,
                  values: state.diskReadHistory,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IoBlock(
                  icon: Icons.arrow_upward_rounded,
                  label: '写入',
                  rate: state.diskWriteRate,
                  total: state.info.totalWriteBytes,
                  values: state.diskWriteHistory,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          if (usages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 4),
            for (final usage in usages)
              UsageBar(
                title: '${usage.path}  ·  ${usage.fstype}',
                subtitle:
                    '已用 ${formatBytes(usage.used)} / 共 ${formatBytes(usage.total)}'
                    '，可用 ${formatBytes(usage.free)}',
                percent: usage.usedPercent,
              ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              '未获取到分区使用信息',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IoBlock extends StatelessWidget {
  const _IoBlock({
    required this.icon,
    required this.label,
    required this.rate,
    required this.total,
    required this.values,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double rate;
  final int total;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          formatRate(rate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '累计 ${formatBytes(total)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        MiniChart(values: values, color: color, minY: 0, height: 44),
      ],
    );
  }
}
