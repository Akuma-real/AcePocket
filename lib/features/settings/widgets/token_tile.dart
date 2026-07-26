import 'package:flutter/material.dart';

import '../models/user_token.dart';
import 'format_utils.dart';

/// API 令牌列表项。
class TokenTile extends StatelessWidget {
  const TokenTile({
    super.key,
    required this.token,
    required this.onEdit,
    required this.onDelete,
    this.inUse = false,
  });

  final UserToken token;

  /// 是否为当前 App 正在使用的令牌（与服务器配置中的 tokenId 相同）。
  final bool inUse;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = token.isExpired;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '令牌 #${token.id}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      if (inUse)
                        _Badge(
                          text: '当前使用',
                          color: theme.colorScheme.primaryContainer,
                          textColor: theme.colorScheme.onPrimaryContainer,
                        ),
                      if (expired) ...[
                        if (inUse) const SizedBox(width: 6),
                        _Badge(
                          text: '已过期',
                          color: theme.colorScheme.errorContainer,
                          textColor: theme.colorScheme.onErrorContainer,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '创建时间：${formatDateTime(token.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '过期时间：${formatDateTime(token.expiredAt)}'
                    '${token.expiredAt == null ? '' : '（${formatRelativeToNow(token.expiredAt!)}）'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: expired
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'IP 白名单：${token.ips.isEmpty ? '不限制' : token.ips.join('，')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('编辑'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      '删除',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}
