/// SSH 主机模块的时间格式化工具。
///
/// 体积格式化统一用 `lib/core/utils/format.dart` 的 `formatBytes`
/// （本文件此前的副本已删除，避免各模块口径不一致）。
library;

import 'package:intl/intl.dart';

final DateFormat _fullFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final DateFormat _shortFormat = DateFormat('yyyy-MM-dd HH:mm');

/// 完整时间，空值展示 `—`。
///
/// 面板返回带时区偏移的 RFC3339，`DateTime.parse` 得到 UTC 实例，
/// 必须 `.toLocal()` 后再格式化（对已是本地时区的实例是空操作）。
String formatDateTime(DateTime? time) =>
    time == null ? '—' : _fullFormat.format(time.toLocal());

/// 简短时间（不含秒），空值展示 `—`。
String formatShortTime(DateTime? time) =>
    time == null ? '—' : _shortFormat.format(time.toLocal());
