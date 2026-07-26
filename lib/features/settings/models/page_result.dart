/// 面板统一分页响应：`{ "total": int, "items": [...] }`
///
/// 对应面板源码 `internal/service/respond.go` 的 `Page[T]`
/// 与各 Service 手动组装的 `chix.M{"total": ..., "items": ...}`。
class PageResult<T> {
  const PageResult({required this.items, required this.total});

  final List<T> items;
  final int total;

  bool get isEmpty => items.isEmpty;

  /// [data] 为 ApiClient 解包后的 `data` 字段。
  /// 容忍 data 为 null（返回空页）或直接是数组（无 total 时以数组长度为总数）。
  factory PageResult.fromJson(
    dynamic data,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    if (data is List) {
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(itemFromJson)
          .toList(growable: false);
      return PageResult<T>(items: items, total: items.length);
    }
    if (data is Map<String, dynamic>) {
      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(itemFromJson)
              .toList(growable: false)
          : <T>[];
      final rawTotal = data['total'];
      final total = rawTotal is num
          ? rawTotal.toInt()
          : (rawTotal is String ? int.tryParse(rawTotal) ?? items.length : items.length);
      return PageResult<T>(items: items, total: total);
    }
    return PageResult<T>(items: const [], total: 0);
  }
}
