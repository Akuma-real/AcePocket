import 'package:flutter/material.dart';

/// 字符串列表编辑器（用于「备份目录」这类需要手动输入多个值的字段）。
class StringListEditor extends StatelessWidget {
  const StringListEditor({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hintText = '',
    this.addLabel = '添加',
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => onChanged([...values, '']),
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
        if (values.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '尚未添加',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < values.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('string-list-$label-$i'),
                    initialValue: values[i],
                    autocorrect: false,
                    decoration: InputDecoration(hintText: hintText),
                    onChanged: (v) {
                      final next = List.of(values);
                      next[i] = v;
                      onChanged(next);
                    },
                  ),
                ),
                IconButton(
                  tooltip: '移除',
                  icon: Icon(Icons.remove_circle_outline,
                      color: theme.colorScheme.error),
                  onPressed: () {
                    final next = List.of(values)..removeAt(i);
                    onChanged(next);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
