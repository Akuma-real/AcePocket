import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_snack.dart' as app_snack;

/// 统一的轻提示（转发到 core 的 `app_snack`）。
///
/// 旧实现只把背景改成 `errorContainer`、图标与关闭按钮都没有，
/// 长错误文案还会把 SnackBar 撑满半屏；core 版本用成对配色 + 图标 +
/// 关闭按钮 + `maxLines: 4`，深浅色主题下均满足对比度要求。
void showSnack(BuildContext context, String message, {bool error = false}) {
  if (error) {
    // 包一层 ApiException：`describeError` 对 ApiException 直接取 message，
    // 传裸 String 时 `Exception: ` 前缀正则不匹配，会带出多余文字。
    app_snack.showErrorSnack(context, ApiException(message));
  } else {
    app_snack.showSuccessSnack(context, message);
  }
}

/// 把异常转成可展示的文案（[ApiException] 取 message）。
String errorMessage(Object error) => describeError(error);

/// 展示异常轻提示。
void showErrorSnack(BuildContext context, Object error) =>
    app_snack.showErrorSnack(context, error);
