/// 仪表盘与监控模块通用的数值 / 时间格式化工具。
///
/// 字节体积、速率、百分比、时长统一复用 core 的唯一实现
/// （`lib/core/utils/format.dart`），本文件只保留监控模块特有的
/// 单位换算（MB / KB/s 序列）与时间格式化。
library;

import 'dart:ui' show FontFeature;

import 'package:intl/intl.dart';

import '../../../core/utils/format.dart';

export '../../../core/utils/format.dart'
    show formatBytes, formatBytesRate, formatPercent;

/// 等宽数字排版。
///
/// 首页实时数值每 3 秒刷新一次，默认的比例数字宽度逐位不同（`1` 比 `8` 窄），
/// 数值一变，同一行里的相邻文字就会左右挪动，整屏看起来在「抖」。
/// 所有会被实时刷新的数字都套这个 feature，让每位数字占同样宽度。
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// 速率（字节/秒）转可读字符串，如 `1.2 MB/s`。
String formatRate(num bytesPerSecond) => formatBytesRate(bytesPerSecond);

/// 以 MB 为单位的数值转可读字符串（监控历史序列的单位为 MB）。
String formatMegabytes(num megabytes, {int fractionDigits = 2}) =>
    formatBytes(megabytes * 1024 * 1024, fractionDigits: fractionDigits);

/// 以 KB/s 为单位的数值转可读速率（磁盘 IO 历史序列的单位为 KB/s）。
String formatKilobytesRate(num kilobytesPerSecond) =>
    formatRate(kilobytesPerSecond * 1024);

/// 以 MB/s 为单位的数值转可读速率（网络历史序列的单位为 MB/s）。
String formatMegabytesRate(num megabytesPerSecond) =>
    formatRate(megabytesPerSecond * 1024 * 1024);

/// 运行时长（秒）转中文文本；面板取不到（≤ 0）时展示占位符。
String formatUptime(int seconds) =>
    seconds <= 0 ? '—' : formatDuration(Duration(seconds: seconds));

/// 统计数量：面板取不到时返回 -1，展示为占位符。
String formatCount(int value) => value < 0 ? '—' : '$value';

final DateFormat _fullFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final DateFormat _dateTimeShortFormat = DateFormat('MM-dd HH:mm');
final DateFormat _timeFormat = DateFormat('HH:mm');

/// 完整时间，空值展示 `—`。
///
/// `DateFormat.format` 按实例自身时区取字段，UTC 实例（`DateTime.parse` 解析
/// 带偏移的 RFC3339 串即为 UTC）会少算时区差，故先转本地时区；对已是本地时区
/// 的实例 `.toLocal()` 是空操作。
String formatDateTime(DateTime? time) =>
    time == null ? '—' : _fullFormat.format(time.toLocal());

/// unix 秒时间戳转完整时间（时间戳是绝对时刻，构造出的实例已是本地时区）。
String formatUnixSeconds(int seconds) => seconds <= 0
    ? '—'
    : _fullFormat.format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));

/// 解析监控接口返回的时间串。
///
/// 面板 `service/monitor.go` 用 Go 的 `time.DateTime` 格式化
/// （`2006-01-02 15:04:05`，无时区后缀），`DateTime.tryParse` 会按本地时区解析，
/// 无需换算。这里仍统一 `.toLocal()`，以便面板日后改为带偏移的 RFC3339 时
/// 依然正确（对无时区串是空操作）。
DateTime? parseMonitorTime(String raw) {
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
}

/// 图表时间轴标签：跨天时带日期。
String formatChartTime(String raw, {required bool withDate}) {
  final time = parseMonitorTime(raw);
  if (time == null) return raw;
  return withDate
      ? _dateTimeShortFormat.format(time)
      : _timeFormat.format(time);
}

/// 图表提示气泡里的时间标签（始终带日期）。
String formatTooltipTime(String raw) {
  final time = parseMonitorTime(raw);
  return time == null ? raw : _dateTimeShortFormat.format(time);
}

/// 图表纵轴刻度：自动按数量级保留小数位。
String formatAxisNumber(double value) {
  final abs = value.abs();
  if (abs >= 1000) return value.toStringAsFixed(0);
  if (abs >= 100) return value.toStringAsFixed(0);
  if (abs >= 10) return value.toStringAsFixed(1);
  if (abs >= 1) return value.toStringAsFixed(1);
  if (abs == 0) return '0';
  return value.toStringAsFixed(2);
}
