/// 应用商店 / 系统服务 / 进程模块内部使用的 JSON 解析辅助函数。
///
/// 面板部分字段在特定场景下会返回 null（如未安装应用的版本、进程无权限读取的字段），
/// 这里统一做容错处理，保证 `fromJson` 不会抛异常。
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
  return const <String>[];
}

/// 解析对象数组。
List<T> jsonList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is List) {
    return v.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }
  return <T>[];
}

Map<String, dynamic> jsonMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}
