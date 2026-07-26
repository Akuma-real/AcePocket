/// 面板用户模块内部使用的 JSON 解析辅助函数（容忍 null / 类型不符）。
library;

int jsonInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

bool jsonBool(dynamic v) => v == true;

String jsonString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return '$v';
}

/// 解析面板返回的 RFC3339 时间（带时区偏移）。
///
/// `DateTime.parse` 得到的是 UTC 实例，必须 `toLocal()` 后再展示，
/// 否则与面板显示相差时区偏移。Go 的零值时间（0001-01-01…）视为 null。
DateTime? jsonTime(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null || t.year <= 1) return null;
  return t.toLocal();
}
