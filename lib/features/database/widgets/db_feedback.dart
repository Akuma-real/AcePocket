import 'package:flutter/material.dart';

import '../../../core/widgets/app_snack.dart';

// 错误文案统一走 core 的 describeError（ApiException 取面板 msg，其余异常去掉
// `XxxException: ` 前缀）。本文件曾复制过一份同名实现，现改为转出，避免两处规则漂移。
export '../../../core/api/api_exception.dart' show describeError;

/// 执行一个可能失败的异步操作，成功提示 [success]，失败展示错误信息。
///
/// 提示统一使用 `core/widgets/app_snack.dart`：成功用 `inverseSurface` 组配色，
/// 失败用 `errorContainer` / `onErrorContainer` 成对配色并带关闭按钮，
/// 面板返回的超长 msg 会被截断为 4 行而不是撑满半屏。
///
/// 返回 true 表示成功。
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) showSuccessSnack(context, success);
    return true;
  } catch (error) {
    // 直接把异常对象交给 showErrorSnack：ApiException 会取面板返回的 msg。
    if (context.mounted) showErrorSnack(context, error);
    return false;
  }
}
