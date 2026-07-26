/// 网站模块内的展示格式化工具。
///
/// 字节体积 / 速率 / 百分比统一复用 `core/utils/format.dart`：
/// 本文件曾自带一份基于 `log(bytes) / log(1024)` 的 `formatBytes`，
/// 在 `0 < bytes < 1` 时会算出负下标并抛 `RangeError`（零流量站点在概览页
/// 切到「出站流量」即触发），已删除。其余函数（千分位、耗时、面板时间）
/// 是网站模块特有的，保留在这里。
library;

import 'package:intl/intl.dart';

export '../../../core/utils/format.dart'
    show formatBytes, formatBytesRate, formatPercent;

/// 千分位格式化器（不指定 locale，避免依赖未初始化的本地化数据）。
final NumberFormat _decimal = NumberFormat.decimalPattern();

/// 千分位整数，如 `1,234,567`。
String formatCount(num value) => _decimal.format(value);

/// 紧凑计数，如 `1.2万`；小于一万时按千分位展示。
String formatCompactCount(num value) {
  if (value.abs() < 10000) return formatCount(value);
  if (value.abs() < 100000000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  return '${(value / 100000000).toStringAsFixed(2)}亿';
}

/// 毫秒转可读耗时，如 `320 ms` / `1.25 s`。
String formatMilliseconds(num ms) {
  if (ms.isNaN || ms <= 0) return '0 ms';
  if (ms < 1000) return '${ms.toStringAsFixed(ms < 10 ? 1 : 0)} ms';
  return '${(ms / 1000).toStringAsFixed(2)} s';
}

/// 环比变化：`+12.3%` / `-4.0%` / `—`（基数为 0 时）。
String formatDelta(num current, num previous) {
  if (previous == 0) return current == 0 ? '—' : '新增';
  final delta = (current - previous) / previous * 100;
  final sign = delta >= 0 ? '+' : '';
  return '$sign${delta.toStringAsFixed(1)}%';
}

/// 环比是否为增长（用于着色）；基数为 0 时视为增长。
bool isDeltaPositive(num current, num previous) => current >= previous;

/// 解析面板返回的时间字符串（RFC3339 或 `yyyy-MM-dd HH:mm:ss`）。
DateTime? parsePanelTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(normalized);
  return parsed?.toLocal();
}

/// 展示用日期时间，如 `2026-07-26 15:04`。
String formatDateTime(String? raw, {String placeholder = '—'}) {
  final time = parsePanelTime(raw);
  if (time == null) return placeholder;
  return DateFormat('yyyy-MM-dd HH:mm').format(time);
}

/// 面板到期时间要求的格式：`yyyy-MM-dd HH:mm:ss`（见 `service.UpdateExpireAt`）。
String formatExpireAtPayload(DateTime time) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
