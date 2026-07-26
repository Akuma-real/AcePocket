import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';
import 'formatters.dart';
import 'mini_chart.dart';

/// 网络实时速率卡片：上下行速率 + 迷你趋势图 + 各网卡累计流量。
class NetworkCard extends StatelessWidget {
  const NetworkCard({super.key, required this.state});

  final RealtimeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nics = state.info.net.where((n) => n.name != 'lo').toList();

    return SectionCard(
      title: '网络',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RateBlock(
                  icon: Icons.upload_rounded,
                  label: '上行',
                  rate: state.netTxRate,
                  total: state.info.totalBytesSent,
                  values: state.netTxHistory,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RateBlock(
                  icon: Icons.download_rounded,
                  label: '下行',
                  rate: state.netRxRate,
                  total: state.info.totalBytesRecv,
                  values: state.netRxHistory,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          if (nics.isNotEmpty) ...[
            const SizedBox(height: 4),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '网卡明细（${nics.length}）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  for (final nic in nics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nic.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '↑ ${formatBytes(nic.bytesSent)}   '
                            '↓ ${formatBytes(nic.bytesRecv)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateBlock extends StatelessWidget {
  const _RateBlock({
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
