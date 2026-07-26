import 'package:flutter/material.dart';

/// 底部选择器的一个选项。
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

/// 单选底部弹层。返回 null 表示用户取消。
Future<T?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option.value == selected;
                    return ListTile(
                      title: Text(option.label),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(option.subtitle!),
                      trailing: isSelected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      selected: isSelected,
                      onTap: () => Navigator.of(context).pop(option.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 只读的「点击选择」输入框外观（配合 [showOptionPicker] 使用）。
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.helperText,
    this.icon = Icons.expand_more,
  });

  final String label;

  /// 当前值的展示文案。
  final String value;

  final VoidCallback? onTap;
  final String? helperText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(icon, size: 20),
        ),
        child: Text(value, style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

/// 说明性提示条。
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 4),
  });

  final String text;
  final IconData icon;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态标签。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
  });

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;
    switch (tone) {
      case ChipTone.success:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
      case ChipTone.warning:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
      case ChipTone.danger:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
      case ChipTone.neutral:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}

/// [StatusChip] 的色调。
enum ChipTone { neutral, success, warning, danger }

/// 动态字符串列表输入（收件人等），至少保留一行。
class StringListField extends StatefulWidget {
  const StringListField({
    super.key,
    required this.initialValues,
    required this.onChanged,
    this.label = '列表',
    this.hint = '',
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  /// 单条内容的校验器（入参已 trim 且非空）；返回 null 表示通过。
  /// 空条目在回传时会被过滤，因此这里不校验空值。
  final String? Function(String value)? validator;

  @override
  State<StringListField> createState() => _StringListFieldState();
}

class _StringListFieldState extends State<StringListField> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialValues.where((e) => e.trim().isNotEmpty).toList();
    if (initial.isEmpty) {
      _controllers.add(TextEditingController());
    } else {
      for (final value in initial) {
        _controllers.add(TextEditingController(text: value));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
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
      final controller = _controllers.removeAt(index);
      controller.dispose();
      if (_controllers.isEmpty) {
        _controllers.add(TextEditingController());
      }
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
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controllers[i],
                    autocorrect: false,
                    keyboardType: widget.keyboardType,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: widget.validator == null
                        ? null
                        : (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) return null;
                            return widget.validator!(v);
                          },
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _removeAt(i),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
