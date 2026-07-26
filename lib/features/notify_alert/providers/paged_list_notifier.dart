import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paged.dart';

/// 分页列表 Notifier 基类：首屏加载 + 下拉刷新 + 上拉加载更多。
///
/// 子类只需实现 [fetch]（调用对应的分页接口）。
abstract class PagedListNotifier<T>
    extends AutoDisposeAsyncNotifier<PagedState<T>> {
  /// 每页条数（面板分页接口 limit 上限为 10000）。
  static const int pageSize = 20;

  /// 拉取第 [page] 页数据（页码从 1 开始）。
  Future<PageResult<T>> fetch(int page, int limit);

  @override
  Future<PagedState<T>> build() async {
    final result = await fetch(1, pageSize);
    return PagedState<T>(items: result.items, total: result.total, page: 1);
  }

  /// 下拉刷新：重新加载第一页。失败时进入错误态，由 ErrorView 展示并可重试。
  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final result = await fetch(1, pageSize);
      return PagedState<T>(items: result.items, total: result.total, page: 1);
    });
  }

  /// 静默重载第一页：失败时保留现有数据，仅把错误抛给调用方展示。
  ///
  /// 用于增删改之后刷新列表，避免整页闪成错误页。
  Future<void> reload() async {
    final result = await fetch(1, pageSize);
    state = AsyncData(
      PagedState<T>(items: result.items, total: result.total, page: 1),
    );
  }

  /// 上拉加载下一页。已在加载中或没有更多数据时直接返回。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final nextPage = current.page + 1;
    try {
      final result = await fetch(nextPage, pageSize);
      final merged = <T>[...current.items, ...result.items];
      state = AsyncData(PagedState<T>(
        items: merged,
        // 服务端返回空页时以已加载条数为准收尾，避免 total 与实际条数不一致
        // 时「加载更多」被无限触发。
        total: result.items.isEmpty ? merged.length : result.total,
        page: nextPage,
      ));
    } catch (_) {
      // 加载更多失败时保留已有数据，仅结束加载态（错误由调用方提示）。
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// 就地替换列表中的某个条目（用于开关类操作的乐观更新后回填）。
  void replaceWhere(bool Function(T item) test, T value) {
    final current = state.valueOrNull;
    if (current == null) return;
    var changed = false;
    final items = <T>[];
    for (final item in current.items) {
      if (!changed && test(item)) {
        items.add(value);
        changed = true;
      } else {
        items.add(item);
      }
    }
    if (changed) {
      state = AsyncData(current.copyWith(items: items));
    }
  }
}
