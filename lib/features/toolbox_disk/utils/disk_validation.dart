/// 磁盘工具箱专有：LVM 卷组名与挂载选项校验。
library;

/// LVM 名称允许 [A-Za-z0-9+_.-]，且不能以短横线开头；
/// 这里进一步要求以字母、数字或下划线开头，避免 `.name` / `+name` 等歧义名。
final RegExp _vgNamePattern = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9+_.\-]*$');

/// 单个挂载选项 token（如 `noatime`、`uid=1000`）允许的字符。
final RegExp _mountOptionPattern = RegExp(r'^[A-Za-z0-9_.=:/@\-]+$');

/// 校验 LVM 卷组名称。返回 null 表示通过。
String? validateVolumeGroupName(String input) {
  final v = input.trim();
  if (v.isEmpty) return '请输入卷组名称';
  if (v == '.' || v == '..') return '卷组名称不能是 . 或 ..';
  if (v.length > 127) return '卷组名称过长（最多 127 个字符）';
  if (!_vgNamePattern.hasMatch(v)) {
    return '卷组名称只能包含字母、数字和 + _ . -，且需以字母、数字或 _ 开头';
  }
  return null;
}

/// 校验 fstab 挂载选项（逗号分隔，如 `defaults,noatime`）。
///
/// 留空视为通过（按 defaults 处理）；返回 null 表示通过。
String? validateMountOptions(String input) {
  final v = input.trim();
  if (v.isEmpty) return null;
  if (v.contains(RegExp(r'\s'))) {
    return '挂载选项不能包含空格，多个选项用英文逗号分隔，如 defaults,noatime';
  }
  for (final part in v.split(',')) {
    if (part.isEmpty) {
      return '存在多余的逗号，选项之间用单个英文逗号分隔，如 defaults,noatime';
    }
    if (!_mountOptionPattern.hasMatch(part)) {
      return '选项「$part」包含不支持的字符，仅支持字母、数字和 _ . = : / @ -';
    }
  }
  return null;
}
