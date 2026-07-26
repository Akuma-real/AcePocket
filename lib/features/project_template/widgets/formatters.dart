/// 项目与模板模块共用的展示格式化函数。
library;

/// 字节数格式化（1024 进制）。
String formatBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final text = value >= 100 || index == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[index]}';
}

/// 百分比格式化（保留一位小数，整数不带小数点）。
String formatPercent(double value) {
  if (value <= 0) return '0%';
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text%';
}

/// 去掉浮点数多余的 `.0`。
String trimDouble(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
