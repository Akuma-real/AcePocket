import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 统一的轻提示。
void showSnack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? TextStyle(color: colorScheme.onErrorContainer) : null,
        ),
        backgroundColor: error ? colorScheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// 把异常转成可展示的文案（[ApiException] 取 message）。
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}

/// 展示异常轻提示。
void showErrorSnack(BuildContext context, Object error) =>
    showSnack(context, errorMessage(error), error: true);
