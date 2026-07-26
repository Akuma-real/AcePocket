import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/container.dart';
import '../models/container_compose.dart';
import '../models/container_image.dart';
import '../models/container_inspect.dart';
import '../models/container_network.dart';
import '../models/container_volume.dart';
import '../models/paged.dart';
import '../repo/container_repo.dart';

/// 当前服务器的容器数据仓库。
final containerRepoProvider = Provider<ContainerRepository>(
  (ref) => ContainerRepository(ref.watch(apiClientProvider)),
);

// --------------------------------------------------------------- 分页状态

/// 分页列表状态。
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

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({bool? loadingMore}) => PagedState<T>(
        items: items,
        total: total,
        page: page,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// 分页列表 Notifier 基类：首屏加载、下拉刷新、上拉加载更多。
abstract class PagedNotifier<T>
    extends AutoDisposeAsyncNotifier<PagedState<T>> {
  static const int pageSize = 20;

  /// 拉取指定页数据，由子类实现。
  Future<Paged<T>> fetch(int page, int limit);

  @override
  Future<PagedState<T>> build() async {
    final paged = await fetch(1, pageSize);
    return PagedState<T>(items: paged.items, total: paged.total, page: 1);
  }

  /// 下拉刷新：重新拉取第一页。失败时抛出异常（供页面提示）。
  Future<void> refresh() async {
    final paged = await fetch(1, pageSize);
    state = AsyncData(
      PagedState<T>(items: paged.items, total: paged.total, page: 1),
    );
  }

  /// 静默刷新：用于操作成功后更新列表，失败时保留旧数据不抛出。
  Future<void> reload() async {
    try {
      await refresh();
    } catch (_) {
      // 忽略：用户可下拉重试。
    }
  }

  /// 加载下一页；已到末页或正在加载时忽略。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final paged = await fetch(nextPage, pageSize);
      final merged = [...current.items, ...paged.items];
      state = AsyncData(PagedState<T>(
        items: merged,
        // 空页即视为到底：避免 total 与实际条数不一致时「加载更多」被反复触发
        // （如关键词搜索模式下 fetch 对 page > 1 直接返回空页）。
        total: paged.items.isEmpty ? merged.length : paged.total,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

// ------------------------------------------------------------------ 容器

/// 容器列表搜索关键词（为空时走分页列表接口，非空时走搜索接口）。
///
/// 与列表页同生命周期：页面销毁后自动复位为空。
final containerKeywordProvider = StateProvider.autoDispose<String>((ref) => '');

/// 容器列表。
class ContainersNotifier extends PagedNotifier<ContainerItem> {
  @override
  Future<PagedState<ContainerItem>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(containerRepoProvider);
    // 关键词变化时自动重建。
    ref.watch(containerKeywordProvider);
    return super.build();
  }

  @override
  Future<Paged<ContainerItem>> fetch(int page, int limit) {
    final repo = ref.read(containerRepoProvider);
    final keyword = ref.read(containerKeywordProvider).trim();
    if (keyword.isNotEmpty) {
      // 搜索接口一次性返回全部匹配项，无需再翻页。
      if (page > 1) {
        return Future.value(const Paged(items: <ContainerItem>[], total: 0));
      }
      return repo.searchContainers(keyword);
    }
    return repo.listContainers(page: page, limit: limit);
  }
}

final containersProvider = AsyncNotifierProvider.autoDispose<ContainersNotifier,
    PagedState<ContainerItem>>(ContainersNotifier.new);

/// 单个容器详情。
final containerInspectProvider =
    FutureProvider.autoDispose.family<ContainerInspect, String>(
  (ref, id) => ref.watch(containerRepoProvider).inspectContainer(id),
);

// ------------------------------------------------------------------ 镜像

class ContainerImagesNotifier extends PagedNotifier<ContainerImage> {
  @override
  Future<PagedState<ContainerImage>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(containerRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<ContainerImage>> fetch(int page, int limit) =>
      ref.read(containerRepoProvider).listImages(page: page, limit: limit);
}

final containerImagesProvider = AsyncNotifierProvider.autoDispose<
    ContainerImagesNotifier, PagedState<ContainerImage>>(
  ContainerImagesNotifier.new,
);

// ------------------------------------------------------------------ 网络

class ContainerNetworksNotifier extends PagedNotifier<ContainerNetwork> {
  @override
  Future<PagedState<ContainerNetwork>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(containerRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<ContainerNetwork>> fetch(int page, int limit) =>
      ref.read(containerRepoProvider).listNetworks(page: page, limit: limit);
}

final containerNetworksProvider = AsyncNotifierProvider.autoDispose<
    ContainerNetworksNotifier, PagedState<ContainerNetwork>>(
  ContainerNetworksNotifier.new,
);

// ---------------------------------------------------------------- 存储卷

class ContainerVolumesNotifier extends PagedNotifier<ContainerVolume> {
  @override
  Future<PagedState<ContainerVolume>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(containerRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<ContainerVolume>> fetch(int page, int limit) =>
      ref.read(containerRepoProvider).listVolumes(page: page, limit: limit);
}

final containerVolumesProvider = AsyncNotifierProvider.autoDispose<
    ContainerVolumesNotifier, PagedState<ContainerVolume>>(
  ContainerVolumesNotifier.new,
);

// ------------------------------------------------------------------ 编排

class ContainerComposesNotifier extends PagedNotifier<ContainerCompose> {
  @override
  Future<PagedState<ContainerCompose>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(containerRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<ContainerCompose>> fetch(int page, int limit) =>
      ref.read(containerRepoProvider).listComposes(page: page, limit: limit);
}

final containerComposesProvider = AsyncNotifierProvider.autoDispose<
    ContainerComposesNotifier, PagedState<ContainerCompose>>(
  ContainerComposesNotifier.new,
);

/// 单个编排的内容与环境变量。
final composeDetailProvider =
    FutureProvider.autoDispose.family<ComposeDetail, String>(
  (ref, name) => ref.watch(containerRepoProvider).getCompose(name),
);
