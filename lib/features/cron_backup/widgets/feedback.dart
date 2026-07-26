import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 把异常转换为可展示的中文提示。
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}

/// 普通提示。
void showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 错误提示（错误色背景）。
void showErrorSnack(BuildContext context, Object error) {
  if (!context.mounted) return;
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: colorScheme.errorContainer,
      content: Text(
        describeError(error),
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
    ));
}
