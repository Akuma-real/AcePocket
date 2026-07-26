/// 面板分页响应（`service.Page`：`{"total": n, "items": [...]}`）。
class PageResult<T> {
  const PageResult({required this.total, required this.items});

  final int total;
  final List<T> items;

  /// [data] 为 ApiClient 解包后的 `data` 字段。
  factory PageResult.fromJson(
    dynamic data,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    if (data is! Map<String, dynamic>) {
      return PageResult(total: 0, items: List.unmodifiable(<T>[]));
    }
    final items = <T>[];
    final rawItems = data['items'];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) items.add(parseItem(e));
      }
    }
    final total = data['total'];
    return PageResult(
      total: total is num ? total.toInt() : items.length,
      items: items,
    );
  }
}
