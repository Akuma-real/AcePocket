import 'package:flutter/material.dart';

/// 授权数据库编辑器：以标签形式管理数据库名列表。
class PrivilegesEditor extends StatefulWidget {
  const PrivilegesEditor({
    super.key,
    required this.values,
    required this.onChanged,
    this.label = '授权数据库',
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String label;

  @override
  State<PrivilegesEditor> createState() => _PrivilegesEditorState();
}

class _PrivilegesEditorState extends State<PrivilegesEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty || widget.values.contains(name)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.values, name]);
    _controller.clear();
  }

  void _remove(String name) {
    widget.onChanged(widget.values.where((v) => v != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in widget.values)
                InputChip(
                  label: Text(name),
                  onDeleted: () => _remove(name),
                  deleteIcon: const Icon(Icons.close, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: '输入数据库名'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '添加',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
