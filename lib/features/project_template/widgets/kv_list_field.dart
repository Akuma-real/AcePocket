import 'package:flutter/material.dart';

import '../models/kv_pair.dart';

/// 键值对动态输入列表（对应面板前端的 n-dynamic-input preset="pair"）。
///
/// 用于项目环境变量与模板部署时的自定义变量。
/// 内容变化时通过 [onChanged] 回传去掉空 key 后的列表。
class KvListField extends StatefulWidget {
  const KvListField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValues = const <KvPair>[],
    this.keyHint = '变量名',
    this.valueHint = '变量值',
    this.helper,
  });

  final String label;
  final List<KvPair> initialValues;
  final ValueChanged<List<KvPair>> onChanged;
  final String keyHint;
  final String valueHint;
  final String? helper;

  @override
  State<KvListField> createState() => _KvListFieldState();
}

class _KvListFieldState extends State<KvListField> {
  final List<(TextEditingController, TextEditingController)> _rows = [];

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialValues) {
      _rows.add((
        TextEditingController(text: item.key),
        TextEditingController(text: item.value),
      ));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.$1.dispose();
      row.$2.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (final row in _rows)
        if (row.$1.text.trim().isNotEmpty)
          KvPair(key: row.$1.text.trim(), value: row.$2.text),
    ]);
  }

  void _add() {
    setState(() {
      _rows.add((TextEditingController(), TextEditingController()));
    });
    _emit();
  }

  void _removeAt(int index) {
    setState(() {
      final row = _rows.removeAt(index);
      row.$1.dispose();
      row.$2.dispose();
    });
    _emit();
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
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '未配置',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _rows[i].$1,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: widget.keyHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _rows[i].$2,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: widget.valueHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _removeAt(i),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
