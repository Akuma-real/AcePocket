import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_exception.dart';

/// 把异常转成可直接展示的文案（[ApiException] 取面板返回的 msg）。
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}

/// 统一的顶层提示（成功 / 失败）。
void showSnack(BuildContext context, String message, {bool error = false}) {
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: error ? theme.colorScheme.onErrorContainer : null,
        ),
      ),
      backgroundColor: error ? theme.colorScheme.errorContainer : null,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 4 : 2),
    ),
  );
}

/// 校验是否为合法 IP（IPv4 / IPv6），面板对 DNS 有 `ip` 校验。
bool isIpAddress(String value) => InternetAddress.tryParse(value) != null;

// ------------------------------------------------------------------ 文本输入

/// 单行文本输入对话框，返回用户输入（取消返回 null）。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? label,
  String? hintText,
  String? helperText,
  TextInputType keyboardType = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
  String confirmText = '保存',
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      label: label,
      hintText: hintText,
      helperText: helperText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      confirmText: confirmText,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.label,
    required this.hintText,
    required this.helperText,
    required this.keyboardType,
    required this.inputFormatters,
    required this.confirmText,
    required this.validator,
  });

  final String title;
  final String initialValue;
  final String? label;
  final String? hintText;
  final String? helperText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String confirmText;
  final String? Function(String value)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          helperText: widget.helperText,
          helperMaxLines: 3,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}

/// 整数输入对话框。
Future<int?> showIntInputDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int min,
  required int max,
  String? label,
  String? helperText,
  String confirmText = '保存',
}) async {
  final text = await showTextInputDialog(
    context,
    title: title,
    initialValue: '$initialValue',
    label: label,
    helperText: helperText,
    confirmText: confirmText,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (value) {
      final parsed = int.tryParse(value);
      if (parsed == null) return '请输入数字';
      if (parsed < min || parsed > max) return '请输入 $min ~ $max 之间的数字';
      return null;
    },
  );
  if (text == null) return null;
  return int.tryParse(text);
}

// -------------------------------------------------------------- 带搜索的选择

/// 带搜索框的单选对话框（时区列表等长列表场景）。
Future<String?> showSearchableSelectDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String value,
  String searchHint = '搜索',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SearchableSelectDialog(
      title: title,
      options: options,
      value: value,
      searchHint: searchHint,
    ),
  );
}

class _SearchableSelectDialog extends StatefulWidget {
  const _SearchableSelectDialog({
    required this.title,
    required this.options,
    required this.value,
    required this.searchHint,
  });

  final String title;
  final List<String> options;
  final String value;
  final String searchHint;

  @override
  State<_SearchableSelectDialog> createState() =>
      _SearchableSelectDialogState();
}

class _SearchableSelectDialogState extends State<_SearchableSelectDialog> {
  final TextEditingController _search = TextEditingController();
  late List<String> _filtered = widget.options;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String keyword) {
    final k = keyword.trim().toLowerCase();
    setState(() {
      _filtered = k.isEmpty
          ? widget.options
          : widget.options
              .where((o) => o.toLowerCase().contains(k))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: widget.searchHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        '没有匹配项',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final option = _filtered[index];
                        final selected = option == widget.value;
                        return ListTile(
                          dense: true,
                          title: Text(option),
                          trailing: selected
                              ? Icon(Icons.check,
                                  color: theme.colorScheme.primary)
                              : null,
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ DNS 编辑

/// DNS 编辑结果。
class DnsEditResult {
  const DnsEditResult(this.dns1, this.dns2);

  final String dns1;
  final String dns2;
}

/// DNS 编辑对话框（面板要求两个地址都必须填写且为合法 IP）。
Future<DnsEditResult?> showDnsEditDialog(
  BuildContext context, {
  required String dns1,
  required String dns2,
}) {
  return showDialog<DnsEditResult>(
    context: context,
    builder: (context) => _DnsEditDialog(dns1: dns1, dns2: dns2),
  );
}

class _DnsEditDialog extends StatefulWidget {
  const _DnsEditDialog({required this.dns1, required this.dns2});

  final String dns1;
  final String dns2;

  @override
  State<_DnsEditDialog> createState() => _DnsEditDialogState();
}

class _DnsEditDialogState extends State<_DnsEditDialog> {
  late final TextEditingController _c1 =
      TextEditingController(text: widget.dns1);
  late final TextEditingController _c2 =
      TextEditingController(text: widget.dns2);
  String? _e1;
  String? _e2;

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    if (value.isEmpty) return '请填写 DNS 服务器地址';
    if (!isIpAddress(value)) return '请输入合法的 IP 地址';
    return null;
  }

  void _submit() {
    final v1 = _c1.text.trim();
    final v2 = _c2.text.trim();
    final e1 = _validate(v1);
    final e2 = _validate(v2);
    if (e1 != null || e2 != null) {
      setState(() {
        _e1 = e1;
        _e2 = e2;
      });
      return;
    }
    Navigator.of(context).pop(DnsEditResult(v1, v2));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置 DNS'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c1,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: '首选 DNS',
              hintText: '例如 223.5.5.5',
              errorText: _e1,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c2,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: '备用 DNS',
              hintText: '例如 8.8.8.8',
              errorText: _e2,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

// -------------------------------------------------------------- 字符串列表编辑

/// 字符串列表编辑对话框（NTP 服务器列表）。
///
/// 返回 null 表示取消；返回的列表已去除空项。
Future<List<String>?> showStringListDialog(
  BuildContext context, {
  required String title,
  required List<String> values,
  required List<String> presets,
  String itemLabel = '地址',
  String? helperText,
  bool allowEmpty = false,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _StringListDialog(
      title: title,
      values: values,
      presets: presets,
      itemLabel: itemLabel,
      helperText: helperText,
      allowEmpty: allowEmpty,
    ),
  );
}

class _StringListDialog extends StatefulWidget {
  const _StringListDialog({
    required this.title,
    required this.values,
    required this.presets,
    required this.itemLabel,
    required this.helperText,
    required this.allowEmpty,
  });

  final String title;
  final List<String> values;
  final List<String> presets;
  final String itemLabel;
  final String? helperText;
  final bool allowEmpty;

  @override
  State<_StringListDialog> createState() => _StringListDialogState();
}

class _StringListDialogState extends State<_StringListDialog> {
  late List<TextEditingController> _controllers = widget.values
      .map((v) => TextEditingController(text: v))
      .toList(growable: true);
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _add([String value = '']) {
    setState(() => _controllers.add(TextEditingController(text: value)));
  }

  void _removeAt(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  void _reset() {
    setState(() {
      for (final c in _controllers) {
        c.dispose();
      }
      _controllers = widget.presets
          .map((v) => TextEditingController(text: v))
          .toList(growable: true);
      _error = null;
    });
  }

  void _submit() {
    final values = _controllers
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (!widget.allowEmpty && values.isEmpty) {
      setState(() => _error = '至少需要保留一个${widget.itemLabel}');
      return;
    }
    if (values.toSet().length != values.length) {
      setState(() => _error = '${widget.itemLabel}不能重复');
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.helperText != null) ...[
                Text(
                  widget.helperText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: '${widget.itemLabel} ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '删除',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _removeAt(i),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _add(),
                    icon: const Icon(Icons.add),
                    label: Text('添加${widget.itemLabel}'),
                  ),
                  const Spacer(),
                  if (widget.presets.isNotEmpty)
                    TextButton(
                      onPressed: _reset,
                      child: const Text('恢复默认'),
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
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

// ------------------------------------------------------------------ 同步时间

/// 同步时间的服务器选择结果：空字符串表示由面板自动挑选延迟最低的内置服务器。
Future<String?> showSyncTimeDialog(
  BuildContext context, {
  required List<String> candidates,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SyncTimeDialog(candidates: candidates),
  );
}

class _SyncTimeDialog extends StatefulWidget {
  const _SyncTimeDialog({required this.candidates});

  final List<String> candidates;

  @override
  State<_SyncTimeDialog> createState() => _SyncTimeDialogState();
}

class _SyncTimeDialogState extends State<_SyncTimeDialog> {
  /// 空串代表「自动选择」。
  String _selected = '';
  final TextEditingController _custom = TextEditingController();
  bool _useCustom = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit() {
    if (_useCustom) {
      Navigator.of(context).pop(_custom.text.trim());
      return;
    }
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('同步时间'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '从 NTP 服务器获取标准时间并写入系统时钟。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _useCustom ? '__custom__' : _selected,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _useCustom = value == '__custom__';
                    if (!_useCustom) _selected = value;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<String>(
                      value: '',
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('自动选择（延迟最低的内置服务器）'),
                    ),
                    for (final server in widget.candidates)
                      RadioListTile<String>(
                        value: server,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(server),
                      ),
                    const RadioListTile<String>(
                      value: '__custom__',
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('自定义服务器'),
                    ),
                  ],
                ),
              ),
              if (_useCustom)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: _custom,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'NTP 服务器地址',
                      hintText: '例如 ntp.aliyun.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
        FilledButton(onPressed: _submit, child: const Text('立即同步')),
      ],
    );
  }
}
