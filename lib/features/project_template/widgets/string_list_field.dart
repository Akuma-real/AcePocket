import 'package:flutter/material.dart';

import '../../../core/widgets/a11y.dart';

/// 字符串动态输入列表（对应面板前端的 n-dynamic-input）。
///
/// 用于 systemd 的依赖服务、启动顺序、读写 / 只读路径等多值字段。
/// 内容变化时通过 [onChanged] 回传去空后的列表；为空时不保留占位行。
class StringListField extends StatefulWidget {
  const StringListField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValues = const <String>[],
    this.hint = '',
    this.helper,
    this.addLabel = '添加',
  });

  final String label;
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;
  final String hint;
  final String? helper;
  final String addLabel;

  @override
  State<StringListField> createState() => _StringListFieldState();
}

class _StringListFieldState extends State<StringListField> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (final value in widget.initialValues) {
      if (value.trim().isEmpty) continue;
      _controllers.add(TextEditingController(text: value));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_controllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList());
  }

  void _add() {
    setState(() => _controllers.add(TextEditingController()));
    _emit();
  }

  void _removeAt(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
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
              label: Text(widget.addLabel),
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
        if (_controllers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '未配置',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: widget.hint.isEmpty ? null : widget.hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                A11yIconButton(
                  tooltip: '删除第 ${i + 1} 行${widget.label}',
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
