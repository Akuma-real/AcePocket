import 'package:flutter/material.dart';

import '../../../core/widgets/a11y.dart';

/// 键值对条目（请求头编辑用；保持顺序，允许键暂时为空）。
class KvEntry {
  KvEntry({required this.key, required this.value});

  String key;
  String value;
}

/// 一行键值对的输入控制器；实例本身即该行的稳定身份。
class _KvRow {
  _KvRow(String key, String value)
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  KvEntry toEntry() =>
      KvEntry(key: keyController.text, value: valueController.text);

  bool matches(KvEntry entry) =>
      keyController.text == entry.key && valueController.text == entry.value;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

/// 键值对编辑器（用于 URL 任务的自定义请求头）。
///
/// 与 [StringListEditor] 同样的坑：早先用 `ValueKey('kv-key-$i')` +
/// `initialValue` 标识每行，删除中间一行后 Flutter 按下标复用旧 Element，
/// 界面仍显示被删行的名称 / 值，提交出去的却是后一行的数据。
/// 现在每行持有自己的 [TextEditingController]，显示与数据始终一致。
class KvEditor extends StatefulWidget {
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
  State<KvEditor> createState() => _KvEditorState();
}

class _KvEditorState extends State<KvEditor> {
  final List<_KvRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _syncFromEntries();
  }

  @override
  void didUpdateWidget(covariant KvEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 自己触发的增删改回流到这里时内容已一致，跳过以保住光标位置。
    if (!_matchesEntries()) _syncFromEntries();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool _matchesEntries() {
    if (_rows.length != widget.entries.length) return false;
    for (var i = 0; i < _rows.length; i++) {
      if (!_rows[i].matches(widget.entries[i])) return false;
    }
    return true;
  }

  void _syncFromEntries() {
    final entries = widget.entries;
    while (_rows.length > entries.length) {
      _rows.removeLast().dispose();
    }
    for (var i = 0; i < entries.length; i++) {
      if (i < _rows.length) {
        final row = _rows[i];
        if (row.keyController.text != entries[i].key) {
          row.keyController.text = entries[i].key;
        }
        if (row.valueController.text != entries[i].value) {
          row.valueController.text = entries[i].value;
        }
      } else {
        _rows.add(_KvRow(entries[i].key, entries[i].value));
      }
    }
  }

  List<KvEntry> get _currentEntries =>
      _rows.map((row) => row.toEntry()).toList();

  void _add() {
    setState(() => _rows.add(_KvRow('', '')));
    widget.onChanged(_currentEntries);
  }

  void _removeAt(int index) {
    setState(() => _rows.removeAt(index).dispose());
    widget.onChanged(_currentEntries);
  }

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
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '未设置请求头，点击右上角的「添加」新增一条',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            key: ObjectKey(_rows[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _rows[i].keyController,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: '名称'),
                    onChanged: (_) => widget.onChanged(_currentEntries),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _rows[i].valueController,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: '值'),
                    onChanged: (_) => widget.onChanged(_currentEntries),
                  ),
                ),
                A11yIconButton(
                  tooltip: '移除第 ${i + 1} 个请求头',
                  icon: Icon(Icons.remove_circle_outline,
                      color: theme.colorScheme.error),
                  onPressed: () => _removeAt(i),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
