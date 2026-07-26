/// 磁盘工具箱模块内部使用的 JSON 解析辅助函数（容忍 null / 类型不符）。
///
/// 面板的磁盘接口大量透传 `lsblk` / `smartctl` / `mdadm` 等命令的原始输出，
/// 不同发行版、不同 util-linux 版本的字段类型并不统一
/// （例如 `lsblk -b -J` 的 size 在旧版本是字符串、新版本是数字），
/// 因此这里统一做宽松解析，避免解析失败导致整页不可用。
library;

int jsonInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final trimmed = v.trim();
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt() ?? 0;
  }
  return 0;
}

bool jsonBool(dynamic v) => v == true;

/// 可空布尔：字段缺失时返回 null（用于「SMART 健康状态未知」等场景）。
bool? jsonBoolOrNull(dynamic v) {
  if (v is bool) return v;
  return null;
}

String jsonString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  return '$v';
}

/// 可空数字：字段缺失时返回 null（区分「值为 0」与「没有该字段」）。
num? jsonNumOrNull(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

Map<String, dynamic> jsonMap(dynamic v) {
  if (v is Map) {
    return v.map((key, value) => MapEntry('$key', value));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> jsonMapList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map(jsonMap).toList();
  }
  return <Map<String, dynamic>>[];
}
