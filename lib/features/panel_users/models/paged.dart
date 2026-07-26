/// 分页数据（对应面板接口统一的 `{"total": n, "items": [...]}` 结构）。
///
/// 面板端 Go 空切片可能序列化为 `null`，[Paged.fromJson] 已容忍。
class Paged<T> {
  const Paged({required this.total, required this.items});

  final int total;
  final List<T> items;

  factory Paged.fromJson(
    dynamic json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    if (json is! Map<String, dynamic>) {
      return Paged<T>(total: 0, items: const []);
    }
    final rawItems = json['items'];
    final items = <T>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(itemFromJson(item));
        }
      }
    }
    return Paged<T>(
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}
