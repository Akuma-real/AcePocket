/// 分页响应载荷，对应面板列表接口的 `data: { total, items }`
/// （见源码 `internal/service/project.go`、`internal/service/template.go`）。
class PageResult<T> {
  const PageResult({required this.total, required this.items});

  final int total;
  final List<T> items;

  /// 从响应 data 解析；[itemParser] 负责解析单个条目。
  /// 对 null / 非法结构容错，返回空列表。
  static PageResult<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    if (json is! Map) {
      return PageResult<T>(total: 0, items: <T>[]);
    }
    final items = <T>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(itemParser(Map<String, dynamic>.from(item)));
        }
      }
    }
    return PageResult<T>(
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}

/// 分页列表的 UI 状态（已加载的条目 + 是否还有下一页）。
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.total,
    this.page = 1,
    this.loadingMore = false,
  });

  final List<T> items;
  final int total;

  /// 已加载到的页码（从 1 开始）。
  final int page;

  /// 正在加载下一页。
  final bool loadingMore;

  /// 是否还有未加载的数据。
  bool get hasMore => items.length < total;

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    int? total,
    int? page,
    bool? loadingMore,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}
