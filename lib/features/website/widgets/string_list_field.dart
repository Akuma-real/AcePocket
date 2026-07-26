import 'package:flutter/material.dart';

/// 可增删的字符串列表编辑器（域名、默认文档、TLS 协议、真实 IP 来源等）。
///
/// 内部维护 [TextEditingController]，任何变更都会通过 [onChanged] 回传完整列表；
/// 父级只需把结果写回模型，不必关心控制器生命周期。
class StringListField extends StatefulWidget {
  const StringListField({
    super.key,
    required this.label,
    required this.initialValues,
    required this.onChanged,
    this.hintText,
    this.addButtonText = '添加',
    this.minItems = 0,
    this.keyboardType,
    this.helperText,
    this.itemPrefixIcon,
  });

  final String label;

  /// 初始值；仅在首次构建时读取。
  final List<String> initialValues;

  final ValueChanged<List<String>> onChanged;

  final String? hintText;
  final String addButtonText;

  /// 最少保留的条目数（如域名至少 1 条）。
  final int minItems;

  final TextInputType? keyboardType;
  final String? helperText;
  final IconData? itemPrefixIcon;

  @override
  State<StringListField> createState() => _StringListFieldState();
}

class _StringListFieldState extends State<StringListField> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final values = List<String>.from(widget.initialValues);
    while (values.length < widget.minItems) {
      values.add('');
    }
    _controllers =
        values.map((v) => TextEditingController(text: v)).toList();
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
    if (_controllers.length <= widget.minItems) return;
    final controller = _controllers.removeAt(index);
    controller.dispose();
    setState(() {});
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    keyboardType: widget.keyboardType,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: widget.itemPrefixIcon == null
                          ? null
                          : Icon(widget.itemPrefixIcon, size: 18),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: _controllers.length <= widget.minItems
                      ? null
                      : () => _removeAt(i),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(widget.addButtonText),
          ),
        ),
      ],
    );
  }
}
