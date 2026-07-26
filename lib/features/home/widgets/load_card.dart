import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/panel_models.dart';
import '../providers/home_providers.dart';
import 'formatters.dart';
import 'info_row.dart';

/// 系统负载卡片：1/5/15 分钟平均负载 + 进程数 + 运行时长。
///
/// 负载告警阈值参考面板前端：以 `核心数 × 2` 为满负荷。
class LoadCard extends StatelessWidget {
  const LoadCard({super.key, required this.state, this.systemInfo});

  final RealtimeState state;

  /// 系统信息（可能尚未加载完成，仅用于补充进程数与运行时长）。
  final SystemInfo? systemInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final load = state.info.load;
    final cores = state.info.cores;
    final capacity = cores > 0 ? cores * 2.0 : 0.0;
    final ratio = capacity > 0 ? (load.load1 / capacity * 100) : 0.0;

    return SectionCard(
      title: '系统负载',
      trailing: Text(
        capacity > 0 ? '满负荷 ${capacity.toStringAsFixed(0)}' : '',
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
                child: MetricTile(
                  label: '1 分钟',
                  value: load.load1.toStringAsFixed(2),
                  icon: Icons.speed_rounded,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: '5 分钟',
                  value: load.load5.toStringAsFixed(2),
                  icon: Icons.speed_rounded,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: '15 分钟',
                  value: load.load15.toStringAsFixed(2),
                  icon: Icons.speed_rounded,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          if (capacity > 0) ...[
            const SizedBox(height: 4),
            UsageBar(
              title: '当前负载压力',
              subtitle: '按 $cores 核 × 2 计算',
              percent: ratio.clamp(0, 100).toDouble(),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Inline(
                  icon: Icons.memory_rounded,
                  label: '进程数',
                  value: systemInfo == null ? '—' : '${systemInfo!.procs}',
                ),
              ),
              Expanded(
                child: _Inline(
                  icon: Icons.timer_outlined,
                  label: '运行时长',
                  value: systemInfo == null
                      ? '—'
                      : formatUptime(systemInfo!.uptime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Inline extends StatelessWidget {
  const _Inline({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
