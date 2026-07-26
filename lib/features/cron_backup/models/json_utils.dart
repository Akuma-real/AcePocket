/// 计划任务与备份模块内部使用的 JSON 解析辅助函数（容忍 null / 类型不符）。
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

List<String> jsonStringList(dynamic v) {
  if (v is List) {
    return v.where((e) => e != null).map((e) => '$e').toList();
  }
  return <String>[];
}

Map<String, String> jsonStringMap(dynamic v) {
  if (v is Map) {
    final result = <String, String>{};
    v.forEach((key, value) {
      if (key != null) result['$key'] = value == null ? '' : '$value';
    });
    return result;
  }
  return <String, String>{};
}

/// 解析时间字符串；Go 的零值时间（0001-01-01…）视为 null。
DateTime? jsonTime(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null || t.year <= 1) return null;
  return t.toLocal();
}
