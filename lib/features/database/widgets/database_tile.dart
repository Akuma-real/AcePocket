import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/database.dart';
import '../models/db_types.dart';
import 'db_chips.dart';

/// 数据库列表条目。
class DatabaseTile extends StatelessWidget {
  const DatabaseTile({
    super.key,
    required this.database,
    required this.onDelete,
    required this.onChangePassword,
    this.onEditComment,
  });

  final Database database;
  final VoidCallback onDelete;
  final VoidCallback onChangePassword;

  /// 仅 PostgreSQL 支持注释，其它类型传 null。
  final VoidCallback? onEditComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.storage_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  database.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ChipRow(
                  children: [
                    InfoChip(label: dbTypeLabel(database.type)),
                    if (database.server.isNotEmpty)
                      InfoChip(
                        label: database.server,
                        icon: Icons.dns_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                    if (database.encoding.isNotEmpty)
                      InfoChip(
                        label: database.encoding,
                        icon: Icons.translate,
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                  ],
                ),
                if (database.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    database.comment,
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
                case 'password':
                  onChangePassword();
                case 'comment':
                  onEditComment?.call();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'password',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.key_outlined),
                  title: Text('修改用户密码'),
                ),
              ),
              if (onEditComment != null)
                const PopupMenuItem(
                  value: 'comment',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_note_outlined),
                    title: Text('设置注释'),
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
                    '删除数据库',
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
