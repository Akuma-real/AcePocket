import 'package:flutter/material.dart';

/// 键值对条目（请求头编辑用；保持顺序，允许键暂时为空）。
class KvEntry {
  KvEntry({required this.key, required this.value});

  String key;
  String value;
}

/// 键值对编辑器（用于 URL 任务的自定义请求头）。
class KvEditor extends StatelessWidget {
  const KvEditor({
    super.key,
    required this.label,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final List<KvEntry> entries;
  final ValueChanged<List<KvEntry>> onChanged;

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
              onPressed: () => onChanged(
                [...entries, KvEntry(key: '', value: '')],
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '未设置请求头',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: ValueKey('kv-key-$i'),
                    initialValue: entries[i].key,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: '名称'),
                    onChanged: (v) {
                      entries[i].key = v;
                      onChanged(List.of(entries));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    key: ValueKey('kv-value-$i'),
                    initialValue: entries[i].value,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: '值'),
                    onChanged: (v) {
                      entries[i].value = v;
                      onChanged(List.of(entries));
                    },
                  ),
                ),
                IconButton(
                  tooltip: '移除',
                  icon: Icon(Icons.remove_circle_outline,
                      color: theme.colorScheme.error),
                  onPressed: () {
                    final next = List.of(entries)..removeAt(i);
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
