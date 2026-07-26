/// 分页列表状态（供本模块各列表 Notifier 复用）。
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
  });

  final List<T> items;

  /// 服务端返回的总条数。
  final int total;

  /// 已加载到的页码（从 1 开始）。
  final int page;

  /// 是否正在加载下一页。
  final bool loadingMore;

  /// 是否还有更多数据。
  bool get hasMore => items.length < total;

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    int? total,
    int? page,
    bool? loadingMore,
  }) =>
      PagedState<T>(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}
