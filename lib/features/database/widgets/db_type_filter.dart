import 'package:flutter/material.dart';

import '../models/db_types.dart';

/// AppBar 上的类型筛选按钮。[value] 为空串表示「全部类型」。
class DbTypeFilterButton extends StatelessWidget {
  const DbTypeFilterButton({
    super.key,
    required this.value,
    required this.types,
    required this.onChanged,
  });

  final String value;
  final List<String> types;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = value.isEmpty ? '全部类型' : dbTypeLabel(value);
    return PopupMenuButton<String>(
      tooltip: '按类型筛选',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('全部类型')),
        const PopupMenuDivider(),
        for (final type in types)
          PopupMenuItem(value: type, child: Text(dbTypeLabel(type))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            // 面板返回未登记的类型时 label 会是原始英文串，限宽省略以免顶栏溢出。
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
