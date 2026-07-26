import '../../../core/providers/paged_notifier_base.dart';
import '../models/paged.dart';

export '../../../core/providers/paged_notifier_base.dart' show PagedState;

/// 分页列表 Notifier 基类：首屏加载 + 下拉刷新 + 上拉加载更多。
///
/// 并发控制（请求代次 / 在途标志 / loadMoreError）由 [PagedAsyncNotifier]
/// 统一提供；子类只需实现 [fetch]（调用对应的分页接口）。
abstract class PagedListNotifier<T> extends PagedAsyncNotifier<T> {
  /// 拉取第 [page] 页数据（页码从 1 开始）。
  Future<PageResult<T>> fetch(int page, int limit);

  @override
  Future<PagedResult<T>> fetchPage(int page, int limit) async {
    final result = await fetch(page, limit);
    return PagedResult(items: result.items, total: result.total);
  }

  /// 下拉刷新：重新加载第一页。失败时进入错误态，由 ErrorView 展示并可重试。
  Future<void> refresh() => reloadFirstPage(toErrorState: true);

  /// 静默重载第一页：失败时保留现有数据，仅把错误抛给调用方展示。
  ///
  /// 用于增删改之后刷新列表，避免整页闪成错误页。
  Future<void> reload() => reloadFirstPage(toErrorState: false);
}
