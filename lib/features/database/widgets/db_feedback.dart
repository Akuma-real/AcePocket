import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 把任意异常转成可直接展示给用户的文案。
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}

/// 顶部消息提示。
void showMessage(BuildContext context, String text, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            color: error ? scheme.onErrorContainer : scheme.onInverseSurface,
          ),
        ),
        backgroundColor: error ? scheme.errorContainer : scheme.inverseSurface,
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

/// 执行一个会失败的异步操作，成功提示 [success]，失败提示错误信息。
///
/// 返回 true 表示成功。
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) showMessage(context, success);
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, describeError(error), error: true);
    return false;
  }
}
