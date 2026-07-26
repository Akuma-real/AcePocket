import 'package:intl/intl.dart';

/// 容器模块 JSON 解析与展示的公共辅助函数。
///
/// 面板响应字段全部按源码 `pkg/types/container*.go` 与 Docker 原生 inspect
/// 输出解析，所有函数对 null / 类型不符的输入均返回安全默认值。

/// 任意值转字符串（null -> [fallback]）。
String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return '$value';
}

/// 任意值转 int（支持数字与数字字符串）。
int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// 任意值转 bool。
bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

/// 任意值转 Map（非 Map 时返回空 Map）。
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return const <String, dynamic>{};
}

/// 任意值转字符串 Map（Docker 的 Labels 等）。
Map<String, String> asStringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  final result = <String, String>{};
  value.forEach((key, val) => result['$key'] = asString(val));
  return result;
}

/// 任意值转字符串列表。
List<String> asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value.map(asString).where((e) => e.isNotEmpty).toList();
}

/// 解析 Go `time.Time`（RFC3339）。
///
/// Go 的零值时间 `0001-01-01T00:00:00Z` 视为「无」，返回 null。
/// 同时兼容 Unix 秒级时间戳（数字）。
DateTime? asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    if (value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000).toLocal();
  }
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  if (parsed.year <= 1) return null;
  return parsed.toLocal();
}

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

/// 时间展示（null 显示 `-`）。
String formatDateTime(DateTime? value) =>
    value == null ? '-' : _dateTimeFormat.format(value);

/// 相对时间展示，如「3 天前」。
String formatRelative(DateTime? value) {
  if (value == null) return '-';
  final diff = DateTime.now().difference(value);
  if (diff.isNegative) return formatDateTime(value);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
  return '${(diff.inDays / 365).floor()} 年前';
}

/// 字节数格式化（面板部分接口已返回格式化字符串，此处用于本地计算的数值）。
String formatBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final text = value >= 100 || unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text ${units[unitIndex]}';
}

/// 截断长 ID（Docker ID 通常展示前 12 位；`sha256:` 前缀会被去掉）。
String shortId(String id, [int length = 12]) {
  var value = id;
  final colon = value.indexOf(':');
  if (colon >= 0 && colon < value.length - 1) {
    value = value.substring(colon + 1);
  }
  return value.length > length ? value.substring(0, length) : value;
}
