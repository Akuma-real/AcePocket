import '../../../core/providers/paged_notifier_base.dart';
import '../models/page_result.dart';

export '../../../core/providers/paged_notifier_base.dart' show PagedState;

/// 分页列表 Notifier 基类。
///
/// 并发控制（请求代次 / 在途标志 / loadMoreError）由 [PagedAsyncNotifier]
/// 统一提供；子类实现 [fetch]，即可获得下拉刷新（[refresh]）与
/// 加载更多（`loadMore`）。
abstract class PagedNotifier<T> extends PagedAsyncNotifier<T> {
  /// 拉取指定页数据。
  Future<PageResult<T>> fetch(int page, int limit);

  @override
  Future<PagedResult<T>> fetchPage(int page, int limit) async {
    final result = await fetch(page, limit);
    return PagedResult(items: result.items, total: result.total);
  }

  /// 下拉刷新：重新拉取第一页。失败时保留旧数据并抛出异常，由页面提示。
  Future<void> refresh() => reloadFirstPage(toErrorState: false);

  /// 数据变更（增删改）后静默重载：失败时把错误状态交给页面展示。
  Future<void> reload() => reloadFirstPage(toErrorState: true);
}
