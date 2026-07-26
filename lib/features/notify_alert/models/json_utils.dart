/// 告警与通知模块内部使用的 JSON 解析辅助函数（容忍 null / 类型不符）。
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
    return v
        .where((e) => e != null)
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return <String>[];
}

List<int> jsonIntList(dynamic v) {
  if (v is List) {
    return v.where((e) => e != null).map(jsonInt).toList();
  }
  return <int>[];
}

Map<String, dynamic> jsonMap(dynamic v) {
  if (v is Map) {
    return Map<String, dynamic>.from(v);
  }
  return <String, dynamic>{};
}

/// 解析面板返回的 RFC3339 时间串。
///
/// 面板返回带时区偏移（如 `2026-07-26T18:13:00+08:00`），`DateTime.parse`
/// 会得到 UTC 实例，必须 `toLocal()` 后再展示。Go 的零值时间
/// （`0001-01-01T00:00:00Z`）视为 null。
DateTime? jsonTime(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null || t.year <= 1) return null;
  return t.toLocal();
}
