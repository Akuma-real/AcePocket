/// 应用分类（对应面板 `GET /api/app/categories` 返回的 `types.LV`）。
class AppCategory {
  const AppCategory({required this.label, required this.value});

  /// 分类显示名。
  final String label;

  /// 分类 slug（作为 `/app/list` 的 `category` 参数）。
  final String value;

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}
