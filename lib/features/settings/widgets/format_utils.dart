import 'package:intl/intl.dart';

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

/// 字节数格式化（日志文件大小）。
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text ${units[unit]}';
}
