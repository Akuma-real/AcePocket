import 'package:flutter/material.dart';

/// 添加自定义 systemd 服务名。
///
/// 面板没有列出全部系统服务的接口，此处由用户输入服务名（unit 名），
/// 保存在本地并按名称查询状态。返回输入的服务名，取消时返回 null。
Future<String?> showAddServiceDialog(
  BuildContext context, {
  required List<String> existing,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AddServiceDialog(existing: existing),
  );
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog({required this.existing});

  final List<String> existing;

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// 常见服务名快捷输入。
  static const _suggestions = <String>[
    'sshd',
    'crond',
    'firewalld',
    'docker',
    'nginx',
    'mysqld',
    'redis',
    'postgresql',
    'fail2ban',
    'supervisord',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('添加服务'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'systemd 服务名',
                  hintText: '如 sshd、docker、nginx',
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return '请输入服务名';
                  if (name.contains(' ')) return '服务名不能包含空格';
                  if (widget.existing.contains(name)) return '该服务已在列表中';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                '常用服务',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in _suggestions)
                    ActionChip(
                      label: Text(name),
                      onPressed: () {
                        _controller.text = name;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: name.length),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
