import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/cron.dart';
import '../repo/cron_repo.dart';
import 'paged_state.dart';

/// 计划任务仓库（跟随当前选中的服务器变化）。
final cronRepoProvider = Provider<CronRepo>((ref) {
  return CronRepo(ref.watch(apiClientProvider));
});

/// 每页条数。
const kCronPageSize = 20;

/// 计划任务列表（分页 + 下拉刷新）。
final cronListProvider =
    AsyncNotifierProvider.autoDispose<CronListNotifier, PagedState<Cron>>(
        CronListNotifier.new);

class CronListNotifier extends AutoDisposeAsyncNotifier<PagedState<Cron>> {
  @override
  Future<PagedState<Cron>> build() async {
    final repo = ref.watch(cronRepoProvider);
    final result = await repo.list(page: 1, limit: kCronPageSize);
    return PagedState(items: result.items, total: result.total, page: 1);
  }

  /// 下拉刷新：重新加载第一页，不清空当前内容。
  Future<void> refresh() async {
    final repo = ref.read(cronRepoProvider);
    state = await AsyncValue.guard(() async {
      final result = await repo.list(page: 1, limit: kCronPageSize);
      return PagedState<Cron>(
        items: result.items,
        total: result.total,
        page: 1,
      );
    });
  }

  /// 加载下一页。失败时抛出异常由调用方提示。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final repo = ref.read(cronRepoProvider);
      final next = current.page + 1;
      final result = await repo.list(page: next, limit: kCronPageSize);
      final merged = [...current.items, ...result.items];
      state = AsyncData(PagedState<Cron>(
        items: merged,
        // 空页即视为到底，避免 total 与实际条数不一致时反复触发「加载更多」。
        total: result.items.isEmpty ? merged.length : result.total,
        page: next,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// 启用 / 停用任务（成功后就地更新列表项）。
  Future<void> setStatus(Cron cron, bool status) async {
    await ref.read(cronRepoProvider).setStatus(cron.id, status);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items
          .map((e) => e.id == cron.id ? e.copyWith(status: status) : e)
          .toList(),
    ));
  }

  /// 删除任务（成功后从列表移除）。
  Future<void> delete(int id) async {
    await ref.read(cronRepoProvider).delete(id);
    final current = state.valueOrNull;
    if (current == null) return;
    final items = current.items.where((e) => e.id != id).toList();
    state = AsyncData(current.copyWith(
      items: items,
      total: current.total > 0 ? current.total - 1 : 0,
    ));
  }
}
