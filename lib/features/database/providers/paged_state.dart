import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page_data.dart';

/// 列表页默认每页条数。
const int kDatabasePageSize = 20;

/// 「下拉刷新 + 上拉分页」列表的 UI 状态。
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// 已加载的全部条目（累加）。
  final List<T> items;

  /// 服务端返回的总条数。
  final int total;

  /// 已加载到的页码（从 1 开始）。
  final int page;

  /// 是否还有下一页。
  final bool hasMore;

  /// 是否正在加载下一页。
  final bool isLoadingMore;

  /// 加载下一页时的错误（在列表底部展示并可重试）。
  final Object? loadMoreError;

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// 分页取数函数：给定页码与每页条数，返回该页数据。
typedef PageFetcher<T> = Future<PageData<T>> Function(int page, int limit);

/// 加载第一页。
///
/// 注意：面板的 `GET /api/database` 实现为 `database[(page-1)*limit:]`
/// （见 `internal/biz/database.go` 的 `List`），会把偏移之后的**全部**条目返回，
/// 因此这里统一按 [limit] 截断，保证各接口的分页语义一致。
Future<PagedState<T>> loadFirstPage<T>(
  PageFetcher<T> fetch, {
  int limit = kDatabasePageSize,
}) async {
  final data = await fetch(1, limit);
  final items = _truncate(data.items, limit);
  return PagedState<T>(
    items: items,
    total: data.total,
    page: 1,
    hasMore: items.isNotEmpty && items.length < data.total,
  );
}

/// 在 [current] 之后追加下一页。
Future<PagedState<T>> loadNextPage<T>(
  PagedState<T> current,
  PageFetcher<T> fetch, {
  int limit = kDatabasePageSize,
}) async {
  final nextPage = current.page + 1;
  final data = await fetch(nextPage, limit);
  final fresh = _truncate(data.items, limit);
  final merged = <T>[...current.items, ...fresh];
  return PagedState<T>(
    items: merged,
    total: data.total,
    page: nextPage,
    hasMore: fresh.isNotEmpty && merged.length < data.total,
  );
}

/// 分页列表 Notifier 的「加载下一页」通用实现。
///
/// 通过 [read] / [write] 读写 Notifier 的 `state`，
/// 加载过程中会先把 `isLoadingMore` 置为 true 以便列表底部展示进度，
/// 失败时把错误挂到底部而不破坏已加载的数据。
Future<void> runPagedLoadMore<T>(
  AsyncValue<PagedState<T>> Function() read,
  void Function(AsyncValue<PagedState<T>> value) write,
  PageFetcher<T> fetch, {
  int limit = kDatabasePageSize,
}) async {
  final current = read().valueOrNull;
  if (current == null || !current.hasMore || current.isLoadingMore) return;

  write(AsyncData(
    current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
  ));
  try {
    write(AsyncData(await loadNextPage(current, fetch, limit: limit)));
  } catch (error) {
    write(AsyncData(
      current.copyWith(isLoadingMore: false, loadMoreError: error),
    ));
  }
}

List<T> _truncate<T>(List<T> items, int limit) =>
    items.length > limit ? items.sublist(0, limit) : items;
