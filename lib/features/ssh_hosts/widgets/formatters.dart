/// SSH 主机模块的数值 / 时间格式化工具。
library;

import 'package:intl/intl.dart';

const List<String> _byteUnits = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

/// 字节数转可读字符串，如 `1.23 GB`。
String formatBytes(num bytes, {int decimals = 2}) {
  var value = bytes.toDouble();
  if (value.isNaN || value.isInfinite || value < 0) value = 0;
  var index = 0;
  while (value >= 1024 && index < _byteUnits.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(index == 0 ? 0 : decimals)} ${_byteUnits[index]}';
}

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
