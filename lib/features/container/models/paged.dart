/// 面板分页响应（对应源码 `internal/service/helper.go` 的 `Paginate`：
/// `{"total": uint, "items": [...]}`）。
class Paged<T> {
  const Paged({required this.items, required this.total});

  final List<T> items;
  final int total;

  factory Paged.fromJson(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is! Map<String, dynamic>) {
      return Paged<T>(items: <T>[], total: 0);
    }
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    return Paged<T>(items: items, total: total);
  }
}
