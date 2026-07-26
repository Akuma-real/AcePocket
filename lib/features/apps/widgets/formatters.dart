/// 模块内展示格式化工具。
///
/// 体积格式化统一走 `lib/core/utils/format.dart`（唯一实现，已处理
/// NaN / Infinity / 负数等边界），这里只保留一层默认参数封装，
/// 以及一个**不做上限钳制**的 CPU 百分比格式化。
library;

import '../../../core/utils/format.dart' as core;

/// 字节数格式化（1024 进制），如 `1.2 GB`。
///
/// 进程内存动辄几百 MB，1 位小数足够；再多的小数只会让列表更难扫读。
String formatBytes(num bytes) => core.formatBytes(bytes, fractionDigits: 1);

/// 进程 CPU 占用百分比，如 `12.3%`。
///
/// **不能**直接用 `core.formatPercent`：它会把值钳制到 0..100，而
/// gopsutil 的 `Process.CPUPercent()` 是「CPU 时间 / 墙钟时间」，多线程进程在
/// 多核机器上正常会超过 100%（如 8 核跑满为 800%），钳制会把繁忙进程显示成
/// 与单核满载无异，掩盖真实负载。这里只兜底 NaN / 负数。
String formatCpuPercent(num value) {
  final input = value.toDouble();
  if (input.isNaN || input.isInfinite || input < 0) return '0.0%';
  return '${input.toStringAsFixed(1)}%';
}
