import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notify_channel.dart';
import '../providers/notify_alert_providers.dart';
import 'snack.dart';

/// 通知渠道多选（数据来自 `GET /notify/channel/all`）。
///
/// 未选择任何渠道时表示「仅记录不通知」（告警规则）或「不发送事件通知」。
class ChannelSelector extends ConsumerWidget {
  const ChannelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.emptyHint = '尚未创建通知渠道，可先到「通知渠道」页添加。',
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final String emptyHint;

  void _toggle(int id, bool value) {
    final next = List<int>.from(selected);
    if (value) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final channels = ref.watch(allNotifyChannelsProvider);

    return channels.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => Row(
        children: [
          Expanded(
            child: Text(
              '渠道列表加载失败：${errorMessage(error)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(allNotifyChannelsProvider),
            child: const Text('重试'),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            emptyHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final NotifyChannel channel in list)
              CheckboxListTile(
                value: selected.contains(channel.id),
                onChanged: (value) => _toggle(channel.id, value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(channel.name),
                subtitle: Text(
                  channel.enabled
                      ? '${notifyTypeLabel(channel.type)} · ${channel.summary}'
                      : '${notifyTypeLabel(channel.type)} · 已停用',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}
