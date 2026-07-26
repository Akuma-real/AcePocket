/// 本模块的提示与错误文案统一走 core 实现。
///
/// 历史上这里有一份复制的 `showSnack` / `showErrorSnack` / `describeError`，
/// 错误提示只改了背景色、前景色沿用 SnackBar 默认值，浅色主题下几乎看不清；
/// 现在改为直接转发 `core/widgets/app_snack.dart`（配色成对取自 ColorScheme、
/// 带图标与关闭按钮、文案限 4 行）与 `core/api/api_exception.dart` 的
/// `describeError`，避免两套实现继续分叉。
///
/// 用法：成功用 [showSuccessSnack]，中性提示用 [showInfoSnack]，
/// 失败一律 [showErrorSnack]（入参可为任意异常对象或字符串）。
library;

export '../../../core/api/api_exception.dart' show describeError;
export '../../../core/widgets/app_snack.dart'
    show showErrorSnack, showInfoSnack, showSuccessSnack;
