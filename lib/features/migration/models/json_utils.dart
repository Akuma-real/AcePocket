/// 面板迁移模块内部使用的 JSON 解析辅助函数（容忍 null / 类型不符）。
library;

int jsonInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double jsonDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

bool jsonBool(dynamic v) => v == true;

String jsonString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return '$v';
}

List<String> jsonStringList(dynamic v) {
  if (v is List) {
    return v.where((e) => e != null).map((e) => '$e').toList();
  }
  return <String>[];
}

/// 取出 JSON 对象中的子对象（非 Map 时返回 null）。
Map<String, dynamic>? jsonMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((key, value) => MapEntry('$key', value));
  return null;
}

/// 把 JSON 数组解析成模型列表。
List<T> jsonList<T>(dynamic v, T Function(Map<String, dynamic>) parse) {
  if (v is! List) return <T>[];
  final result = <T>[];
  for (final item in v) {
    final map = jsonMap(item);
    if (map != null) result.add(parse(map));
  }
  return result;
}

/// 解析面板返回的 RFC3339 时间（带时区偏移）。
///
/// `DateTime.parse` 得到的是 UTC 实例，展示前必须 [DateTime.toLocal]，
/// 否则会与面板显示相差时区偏移。Go 的零值时间（0001-01-01…）视为 null。
DateTime? jsonTime(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null || t.year <= 1) return null;
  return t.toLocal();
}

/// 格式化本地时间为 `yyyy-MM-dd HH:mm:ss`。
String formatDateTime(DateTime? time) {
  if (time == null) return '-';
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

// 耗时格式化不再在此处自制：统一使用 core/utils/format.dart 的
// formatDuration(Duration)，避免各模块维护互不一致的实现。
