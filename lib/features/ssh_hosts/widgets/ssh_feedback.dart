import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 统一提取错误文案（[ApiException] 取面板返回的 msg）。
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

/// 通用文本输入对话框，返回用户输入（取消或输入为空返回 null）。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? label,
  String? hintText,
  String? helperText,
  String confirmText = '确定',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            helperText: helperText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final text = value.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
