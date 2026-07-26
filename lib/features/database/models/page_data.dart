/// 分页数据载荷，对应面板列表接口响应 `data: { total, items }`
/// （见源码 `internal/service/respond.go` 的 `Page[T]`）。
class PageData<T> {
  const PageData({required this.total, required this.items});

  final int total;
  final List<T> items;

  /// 从响应 data 解析；[itemParser] 负责解析单个条目。
  /// 对 null / 非法结构容错，返回空列表。
  static PageData<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    if (json is! Map<String, dynamic>) {
      return PageData<T>(total: 0, items: List<T>.unmodifiable(const []));
    }
    final items = <T>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(itemParser(item));
        }
      }
    }
    return PageData<T>(
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}
