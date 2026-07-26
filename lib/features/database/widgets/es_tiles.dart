import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../models/es_models.dart';
import 'db_chips.dart';

/// Elasticsearch 索引条目。
class EsIndexTile extends StatelessWidget {
  const EsIndexTile({
    super.key,
    required this.index,
    required this.onBrowse,
    required this.onDelete,
  });

  final EsIndex index;
  final VoidCallback onBrowse;
  final VoidCallback onDelete;

  Color _healthColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (index.health) {
      case 'green':
        return scheme.tertiary;
      case 'yellow':
        return scheme.secondary;
      case 'red':
        return scheme.error;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onBrowse,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 12, color: _healthColor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  index.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ChipRow(
                  children: [
                    if (index.status.isNotEmpty)
                      InfoChip(label: index.status),
                    if (index.docsCount.isNotEmpty)
                      InfoChip(
                        label: '${index.docsCount} 文档',
                        icon: Icons.description_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                    if (index.storeSize.isNotEmpty)
                      InfoChip(
                        label: index.storeSize,
                        icon: Icons.data_usage,
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
                case 'browse':
                  onBrowse();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'browse',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.list_alt_outlined),
                  title: Text('浏览文档'),
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
                    '删除索引',
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

/// Elasticsearch 文档条目。
class EsDocumentTile extends StatelessWidget {
  const EsDocumentTile({
    super.key,
    required this.document,
    required this.onView,
    required this.onDelete,
  });

  final EsDocument document;
  final VoidCallback onView;
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
                  document.id.isEmpty ? '(无 ID)' : document.id,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  document.source,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
                    '删除文档',
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
