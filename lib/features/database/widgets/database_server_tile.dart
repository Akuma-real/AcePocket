import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/database_server.dart';
import '../models/db_types.dart';
import 'db_chips.dart';

/// 数据库服务器列表条目。
class DatabaseServerTile extends StatelessWidget {
  const DatabaseServerTile({
    super.key,
    required this.server,
    required this.onEdit,
    required this.onEditRemark,
    required this.onSync,
    required this.onDelete,
  });

  final DatabaseServer server;
  final VoidCallback onEdit;
  final VoidCallback onEditRemark;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSync = dbTypeSupportsSync(server.type);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        server.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status: server.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  server.displayAddress,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ChipRow(
                  children: [
                    InfoChip(label: dbTypeLabel(server.type)),
                    if (server.username.isNotEmpty)
                      InfoChip(
                        label: server.username,
                        icon: Icons.person_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                  ],
                ),
                if (server.remark.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    server.remark,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'remark':
                  onEditRemark();
                case 'sync':
                  onSync();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('编辑服务器'),
                ),
              ),
              const PopupMenuItem(
                value: 'remark',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notes_outlined),
                  title: Text('修改备注'),
                ),
              ),
              if (canSync)
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sync),
                    title: Text('同步用户'),
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
                    '删除服务器',
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
