/// 面板统一分页响应。
///
/// 对应源码 `internal/service/helper.go` 的 `Paginate()`：
/// `{"total": <总数>, "items": [...]}`，请求参数为 `page` / `limit`。
class Paged<T> {
  const Paged({required this.items, required this.total});

  final List<T> items;
  final int total;

  factory Paged.parse(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is! Map) return Paged<T>(items: <T>[], total: 0);
    final raw = data['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    return Paged<T>(items: items, total: total);
  }
}

/// 分页列表页面状态（首屏加载 / 加载更多 / 错误 / 是否还有下一页）。
class PagedListState<T> {
  PagedListState({
    List<T>? items,
    this.total = 0,
    this.page = 1,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  }) : items = items ?? <T>[];

  /// 已加载的全部条目。
  final List<T> items;

  /// 服务端返回的总条数。
  final int total;

  /// 已加载到的页码。
  final int page;

  /// 首屏加载中。
  final bool isLoading;

  /// 加载下一页中。
  final bool isLoadingMore;

  /// 首屏加载错误（加载更多失败不写入此字段，由页面以提示条展示）。
  final Object? error;

  /// 是否还有更多数据。
  bool get hasMore => items.length < total;

  /// 首屏加载完成且无数据。
  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  PagedListState<T> copyWith({
    List<T>? items,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
