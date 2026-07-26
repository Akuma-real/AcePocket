import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/db_types.dart';
import '../models/redis_kv.dart';
import 'db_chips.dart';

/// Redis 键值列表条目。
class RedisKeyTile extends StatelessWidget {
  const RedisKeyTile({
    super.key,
    required this.kv,
    required this.onView,
    required this.onTtl,
    required this.onRename,
    required this.onDelete,
  });

  final RedisKv kv;
  final VoidCallback onView;
  final VoidCallback onTtl;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onView,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kv.key,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ChipRow(
                  children: [
                    InfoChip(label: kv.type.isEmpty ? 'unknown' : kv.type),
                    InfoChip(
                      label: kv.ttlText,
                      icon: Icons.timer_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      background: theme.colorScheme.surfaceContainerHighest,
                    ),
                    InfoChip(
                      label: formatBytes(kv.size),
                      icon: Icons.data_usage,
                      color: theme.colorScheme.onSurfaceVariant,
                      background: theme.colorScheme.surfaceContainerHighest,
                    ),
                    if (kv.length > 0)
                      InfoChip(
                        label: '长度 ${kv.length}',
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) {
              switch (value) {
                case 'view':
                  onView();
                case 'ttl':
                  onTtl();
                case 'rename':
                  onRename();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('查看 / 编辑'),
                ),
              ),
              const PopupMenuItem(
                value: 'ttl',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.timer_outlined),
                  title: Text('设置过期时间'),
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.drive_file_rename_outline),
                  title: Text('重命名'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    '删除键',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
