import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page_result.dart';

/// 分页列表状态（首屏 / 下拉刷新 / 上拉加载更多）。
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

  bool get hasMore => items.length < total;

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

/// 分页列表 Notifier 基类。
///
/// 子类实现 [fetch]，即可获得下拉刷新（[refresh]）与加载更多（[loadMore]）。
abstract class PagedNotifier<T>
    extends AutoDisposeAsyncNotifier<PagedState<T>> {
  /// 每页条数。
  static const int pageSize = 20;

  /// 拉取指定页数据。
  Future<PageResult<T>> fetch(int page, int limit);

  @override
  Future<PagedState<T>> build() async {
    final result = await fetch(1, pageSize);
    return PagedState<T>(items: result.items, total: result.total, page: 1);
  }

  /// 下拉刷新：重新拉取第一页。失败时抛出异常，由页面提示。
  Future<void> refresh() async {
    final result = await fetch(1, pageSize);
    state = AsyncData(
      PagedState<T>(items: result.items, total: result.total, page: 1),
    );
  }

  /// 数据变更（增删改）后静默重载：失败时把错误状态交给页面展示。
  Future<void> reload() async {
    state = await AsyncValue.guard(() async {
      final result = await fetch(1, pageSize);
      return PagedState<T>(items: result.items, total: result.total, page: 1);
    });
  }

  /// 加载下一页；已到末页或正在加载时忽略，失败时静默恢复（可再次触发）。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final result = await fetch(nextPage, pageSize);
      final merged = [...current.items, ...result.items];
      state = AsyncData(PagedState<T>(
        items: merged,
        // 服务端返回空页时以已加载条数为准收尾，避免 total 与实际条数不一致
        // 导致「加载更多」被反复触发。
        total: result.items.isEmpty ? merged.length : result.total,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}
