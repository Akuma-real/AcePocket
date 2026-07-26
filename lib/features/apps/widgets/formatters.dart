/// 模块内通用展示格式化工具。
library;

import 'package:intl/intl.dart';

final NumberFormat _intFormat = NumberFormat.decimalPattern('zh_CN');

/// 字节数格式化（1024 进制），如 `1.25 GB`。
String formatBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// 百分比格式化，如 `12.3%`。
String formatPercent(num value) => '${value.toStringAsFixed(1)}%';

/// 整数千分位格式化。
String formatInt(num value) => _intFormat.format(value);
