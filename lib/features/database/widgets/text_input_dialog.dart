import 'package:flutter/material.dart';

/// 通用单字段输入对话框（备注、注释等）。返回 null 表示取消。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? hintText,
  String initialValue = '',
  int maxLines = 1,
  String confirmText = '保存',
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(confirmText),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
