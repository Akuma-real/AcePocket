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
                  // 数据库名可能很长且不含空格（无法自动折行），限宽并省略。
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () => _remove(name),
                  deleteButtonTooltipMessage: '移除授权数据库 $name',
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
              // 读屏只念 tooltip，写清楚动作对象而不是单字「添加」。
              tooltip: '添加授权数据库',
              onPressed: _add,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
