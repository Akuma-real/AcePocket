import 'package:intl/intl.dart';

// 字节格式化统一走 core（`lib/core/utils/format.dart`），本模块曾复制过一份
// 实现；core 版本对 NaN / Infinity / 负数 / 0<x<1 均有兜底，行为完全覆盖旧实现
// （B 档取整、KB 及以上两位小数），故此处直接转出，不再重复实现。
export '../../../core/utils/format.dart' show formatBytes;

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

/// 格式化为 `yyyy-MM-dd HH:mm:ss`，null 显示 `-`。
String formatDateTime(DateTime? time) =>
    time == null ? '-' : _dateTimeFormat.format(time);

/// 格式化为 `yyyy-MM-dd`。
String formatDate(DateTime time) => _dateFormat.format(time);

/// 相对当前时间的粗略描述，如「3 天后过期」「已过期 2 小时」。
String formatRelativeToNow(DateTime time) {
  final diff = time.difference(DateTime.now());
  final abs = diff.abs();
  final String value;
  if (abs.inDays >= 1) {
    value = '${abs.inDays} 天';
  } else if (abs.inHours >= 1) {
    value = '${abs.inHours} 小时';
  } else {
    value = '${abs.inMinutes} 分钟';
  }
  return diff.isNegative ? '已过期 $value' : '$value后过期';
}
