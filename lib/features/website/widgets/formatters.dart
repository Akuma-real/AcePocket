/// 网站模块内的展示格式化工具。
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';

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

/// 字节数转可读体积，如 `1.25 GB`。
String formatBytes(num bytes, {int fractionDigits = 2}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  final i = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1024, i);
  if (i == 0) return '${value.toStringAsFixed(0)} B';
  return '${value.toStringAsFixed(fractionDigits)} ${units[i]}';
}

/// 速率（字节/秒）。
String formatRate(num bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// 毫秒转可读耗时，如 `320 ms` / `1.25 s`。
String formatMilliseconds(num ms) {
  if (ms <= 0) return '0 ms';
  if (ms < 1000) return '${ms.toStringAsFixed(ms < 10 ? 1 : 0)} ms';
  return '${(ms / 1000).toStringAsFixed(2)} s';
}

/// 百分比，如 `12.3%`。
String formatPercent(num value, {int fractionDigits = 1}) =>
    '${value.toStringAsFixed(fractionDigits)}%';

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
