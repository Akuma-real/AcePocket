/// 项目与模板模块共用的展示格式化函数。
///
/// 字节数格式化统一使用 `lib/core/utils/format.dart` 的 `formatBytes`
/// （本文件原先复制了一份实现，缺少 PB/EB 且未处理 NaN/Infinity）。
/// 百分比**不能**复用 core 的 `formatPercent`：它会把值钳制到 0..100，
/// 而 systemd 的 `CPUQuota=` 与多核进程的 CPU 占用都可以超过 100%
/// （200% 表示 2 个核心），钳制会把「2 核」显示成「1 核」。
library;

/// CPU 百分比格式化（保留一位小数，整数不带小数点，**不做 0..100 钳制**）。
String formatCpuPercent(num value) {
  final input = value.toDouble();
  if (input.isNaN || input.isInfinite || input <= 0) return '0%';
  final text = input == input.roundToDouble()
      ? input.toStringAsFixed(0)
      : input.toStringAsFixed(1);
  return '$text%';
}

/// 去掉浮点数多余的 `.0`。
String trimDouble(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
