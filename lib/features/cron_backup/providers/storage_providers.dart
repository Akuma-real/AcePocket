import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/backup_storage.dart';
import '../models/option_item.dart';
import '../repo/backup_storage_repo.dart';
import 'paged_state.dart';

/// 备份存储仓库（跟随当前选中的服务器变化）。
final backupStorageRepoProvider = Provider<BackupStorageRepo>((ref) {
  return BackupStorageRepo(ref.watch(apiClientProvider));
});

/// 每页条数。
const kStoragePageSize = 20;

/// 备份存储列表（分页）。
final backupStorageListProvider = AsyncNotifierProvider.autoDispose<
    BackupStorageListNotifier,
    PagedState<BackupStorage>>(BackupStorageListNotifier.new);

class BackupStorageListNotifier
    extends AutoDisposeAsyncNotifier<PagedState<BackupStorage>> {
  @override
  Future<PagedState<BackupStorage>> build() async {
    final repo = ref.watch(backupStorageRepoProvider);
    final result = await repo.list(page: 1, limit: kStoragePageSize);
    return PagedState(items: result.items, total: result.total, page: 1);
  }

  Future<void> refresh() async {
    final repo = ref.read(backupStorageRepoProvider);
    state = await AsyncValue.guard(() async {
      final result = await repo.list(page: 1, limit: kStoragePageSize);
      return PagedState<BackupStorage>(
        items: result.items,
        total: result.total,
        page: 1,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final repo = ref.read(backupStorageRepoProvider);
      final next = current.page + 1;
      final result = await repo.list(page: next, limit: kStoragePageSize);
      final merged = [...current.items, ...result.items];
      state = AsyncData(PagedState<BackupStorage>(
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

  /// 删除备份存储（成功后从列表移除）。
  Future<void> delete(int id) async {
    await ref.read(backupStorageRepoProvider).delete(id);
    final current = state.valueOrNull;
    if (current == null) return;
    final items = current.items.where((e) => e.id != id).toList();
    state = AsyncData(current.copyWith(
      items: items,
      total: current.total > 0 ? current.total - 1 : 0,
    ));
  }
}

/// 备份存储下拉选项（创建备份 / 备份类计划任务时选择目标存储）。
final storageOptionsProvider =
    FutureProvider.autoDispose<List<StorageOption>>((ref) async {
  final result =
      await ref.watch(backupStorageRepoProvider).list(page: 1, limit: 1000);
  final options = result.items
      .map((e) => StorageOption(id: e.id, name: e.name))
      .toList();
  if (!options.any((e) => e.id == 0)) {
    options.insert(0, const StorageOption(id: 0, name: '本地存储'));
  }
  return options;
});
