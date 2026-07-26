import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/ws_client.dart';

/// 把任意异常转换为可直接展示的中文文案。
String describeError(Object error) {
  if (error is ApiException) return error.message;
  if (error is WsAuthException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
}

/// 展示一条错误提示。
void showErrorSnackBar(BuildContext context, Object error) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          describeError(error),
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
        backgroundColor: colorScheme.errorContainer,
      ),
    );
}

/// 展示一条成功提示。
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 执行一个耗时操作：期间展示不可取消的进度对话框，
/// 成功后弹出 [success] 提示，失败弹出错误提示。返回是否成功。
///
/// 危险操作请先用 core 的 `showConfirmDialog` 二次确认。
Future<bool> runAction(
  BuildContext context, {
  required String pending,
  required Future<void> Function() action,
  String? success,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final colorScheme = Theme.of(context).colorScheme;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _ProgressDialog(message: pending),
  );

  Object? failure;
  try {
    await action();
  } catch (error) {
    failure = error;
  }

  if (navigator.canPop()) navigator.pop();

  if (failure != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            describeError(failure),
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    return false;
  }

  if (success != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(success)));
  }
  return true;
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(message, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
