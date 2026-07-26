import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/paged.dart';
import '../models/ssh_file_info.dart';
import '../models/ssh_host.dart';
import '../repo/ssh_hosts_repo.dart';

/// 当前服务器的 SSH 主机仓库。
final sshHostsRepoProvider = Provider<SshHostsRepository>(
  (ref) => SshHostsRepository(ref.watch(apiClientProvider)),
);

// ------------------------------------------------------------------ 分页列表

/// 分页列表状态。
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
  });

  final List<T> items;
  final int total;

  /// 已加载到的页码（从 1 开始）。
  final int page;

  /// 是否正在加载下一页。
  final bool loadingMore;

  bool get hasMore => items.length < total;

  PagedState<T> copyWith({bool? loadingMore}) => PagedState<T>(
        items: items,
        total: total,
        page: page,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// SSH 主机分页列表：首屏加载、下拉刷新、上拉加载更多。
class SshHostsNotifier extends AutoDisposeAsyncNotifier<PagedState<SshHost>> {
  static const int pageSize = 20;

  Future<Paged<SshHost>> _fetch(int page) =>
      ref.read(sshHostsRepoProvider).list(page: page, limit: pageSize);

  @override
  Future<PagedState<SshHost>> build() async {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(sshHostsRepoProvider);
    final paged = await _fetch(1);
    return PagedState<SshHost>(items: paged.items, total: paged.total, page: 1);
  }

  /// 下拉刷新：重新拉取第一页。失败时抛出异常（供调用方提示）。
  Future<void> refresh() async {
    final paged = await _fetch(1);
    state = AsyncData(
      PagedState<SshHost>(items: paged.items, total: paged.total, page: 1),
    );
  }

  /// 加载下一页；已到末页或正在加载时忽略。加载失败静默恢复（可再次触发）。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final paged = await _fetch(nextPage);
      final merged = [...current.items, ...paged.items];
      state = AsyncData(PagedState<SshHost>(
        items: merged,
        // 空页即视为到底，避免 total 与实际条数不一致时反复触发「加载更多」。
        total: paged.items.isEmpty ? merged.length : paged.total,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// SSH 主机列表。
final sshHostsProvider =
    AsyncNotifierProvider.autoDispose<SshHostsNotifier, PagedState<SshHost>>(
        SshHostsNotifier.new);

// ------------------------------------------------------------------ 详情与选项

/// 单台主机详情（编辑表单回填用；面板会返回解密后的密码 / 私钥）。
final sshHostDetailProvider =
    FutureProvider.autoDispose.family<SshHost, int>((ref, id) {
  return ref.watch(sshHostsRepoProvider).get(id);
});

/// 全部主机（供文件浏览页切换主机；面板 limit 上限 10000，这里取 500 足够）。
final sshHostOptionsProvider =
    FutureProvider.autoDispose<List<SshHost>>((ref) async {
  final paged = await ref.watch(sshHostsRepoProvider).list(page: 1, limit: 500);
  return paged.items;
});

// ------------------------------------------------------------------ SFTP 浏览

/// SFTP 目录查询条件（record，具备结构相等性，可直接作 family 参数）。
///
/// [hostId] 为 0 表示面板本机（面板源码 `request.SSHFile` 的约定）。
typedef SftpQuery = ({int hostId, String path});

/// 指定主机指定目录下的文件列表。
final sftpListingProvider =
    FutureProvider.autoDispose.family<List<SshFileInfo>, SftpQuery>(
  (ref, query) => ref
      .watch(sshHostsRepoProvider)
      .listFiles(hostId: query.hostId, path: query.path),
);
