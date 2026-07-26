import 'package:flutter/material.dart';

import '../models/kv.dart';

/// 键值对编辑器（环境变量、标签、驱动选项等）。
///
/// 内部维护 TextEditingController，值变化时通过 [onChanged] 回传，
/// 空键的行在回传时被自动忽略。
class KvEditor extends StatefulWidget {
  const KvEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.keyHint = '键',
    this.valueHint = '值',
    this.addLabel = '添加一项',
  });

  final List<KV> initialValue;
  final ValueChanged<List<KV>> onChanged;
  final String keyHint;
  final String valueHint;
  final String addLabel;

  @override
  State<KvEditor> createState() => _KvEditorState();
}

class _KvEditorState extends State<KvEditor> {
  final List<_KvRow> _rows = [];

  @override
  void initState() {
    super.initState();
    for (final kv in widget.initialValue) {
      _rows.add(_KvRow.from(kv, _emit));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      _rows
          .where((row) => row.keyController.text.trim().isNotEmpty)
          .map((row) => KV(
                key: row.keyController.text.trim(),
                value: row.valueController.text,
              ))
          .toList(),
    );
  }

  void _add() {
    setState(() => _rows.add(_KvRow.from(const KV(), _emit)));
  }

  void _removeAt(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '暂无内容',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _rows[i].keyController,
                    decoration: InputDecoration(labelText: widget.keyHint),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _rows[i].valueController,
                    decoration: InputDecoration(labelText: widget.valueHint),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  tooltip: '删除该项',
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _removeAt(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
      ],
    );
  }
}

class _KvRow {
  _KvRow(this.keyController, this.valueController, this._onChanged) {
    keyController.addListener(_onChanged);
    valueController.addListener(_onChanged);
  }

  factory _KvRow.from(KV kv, VoidCallback onChanged) => _KvRow(
        TextEditingController(text: kv.key),
        TextEditingController(text: kv.value),
        onChanged,
      );

  final TextEditingController keyController;
  final TextEditingController valueController;
  final VoidCallback _onChanged;

  void dispose() {
    keyController
      ..removeListener(_onChanged)
      ..dispose();
    valueController
      ..removeListener(_onChanged)
      ..dispose();
  }
}
