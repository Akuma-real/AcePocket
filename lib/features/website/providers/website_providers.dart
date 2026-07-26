import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/lv_option.dart';
import '../models/website.dart';
import '../models/website_default_config.dart';
import '../models/website_setting.dart';
import '../repo/website_repo.dart';

/// 网站仓库（依赖当前选中服务器的 ApiClient）。
final websiteRepoProvider = Provider<WebsiteRepo>(
  (ref) => WebsiteRepo(ref.watch(apiClientProvider)),
);

/// 列表页每页条数。
const int kWebsitePageSize = 20;

/// 网站类型筛选：all / proxy / php / static。
final websiteTypeFilterProvider = StateProvider<String>((ref) => 'all');

/// 网站列表分页状态。
class WebsiteListState {
  const WebsiteListState({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Website> items;

  /// 面板返回的网站总数（不随类型筛选变化，仅作展示参考）。
  final int total;

  /// 当前已加载到第几页。
  final int page;

  /// 是否还有下一页。
  final bool hasMore;

  final bool loadingMore;

  /// 加载下一页失败时的错误信息（展示后可继续重试）。
  final String? loadMoreError;

  WebsiteListState copyWith({
    List<Website>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) =>
      WebsiteListState(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError:
            clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

/// 网站列表（下拉刷新 + 上拉分页）。
final websiteListProvider =
    AsyncNotifierProvider<WebsiteListNotifier, WebsiteListState>(
        WebsiteListNotifier.new);

class WebsiteListNotifier extends AsyncNotifier<WebsiteListState> {
  @override
  Future<WebsiteListState> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(websiteRepoProvider);
    // 类型筛选变化时自动重新加载第一页。
    ref.watch(websiteTypeFilterProvider);
    return _loadFirstPage();
  }

  Future<WebsiteListState> _loadFirstPage() async {
    final repo = ref.read(websiteRepoProvider);
    final type = ref.read(websiteTypeFilterProvider);
    final result =
        await repo.list(type: type, page: 1, limit: kWebsitePageSize);
    return WebsiteListState(
      items: result.items,
      total: result.total,
      page: 1,
      hasMore: result.items.length >= kWebsitePageSize &&
          result.items.length < result.total,
    );
  }

  /// 下拉刷新：重新拉取第一页；失败时进入错误态由 ErrorView 展示。
  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadFirstPage);
  }

  /// 静默重载第一页：失败时保留现有数据并把异常抛给调用方提示。
  ///
  /// 用于增删改之后刷新列表，避免整页闪成错误页。
  Future<void> reload() async {
    state = AsyncData(await _loadFirstPage());
  }

  /// 加载下一页；已在加载中 / 无更多数据时直接返回。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(
        current.copyWith(loadingMore: true, clearLoadMoreError: true));
    final nextPage = current.page + 1;
    try {
      final repo = ref.read(websiteRepoProvider);
      final type = ref.read(websiteTypeFilterProvider);
      final result =
          await repo.list(type: type, page: nextPage, limit: kWebsitePageSize);
      final merged = [...current.items, ...result.items];
      state = AsyncData(current.copyWith(
        items: merged,
        total: result.total,
        page: nextPage,
        hasMore: result.items.length >= kWebsitePageSize &&
            merged.length < result.total,
        loadingMore: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        loadingMore: false,
        loadMoreError: e.toString(),
      ));
    }
  }

  /// 本地移除某个网站条目（删除成功后即时反馈，随后仍会刷新）。
  void removeItem(int id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items.where((e) => e.id != id).toList(growable: false),
      total: current.total > 0 ? current.total - 1 : 0,
    ));
  }
}

/// 单个网站的完整配置。
final websiteSettingProvider =
    FutureProvider.autoDispose.family<WebsiteSetting, int>(
  (ref, id) => ref.watch(websiteRepoProvider).getSetting(id),
);

/// 已安装环境（PHP 版本 / 数据库类型 / Web 服务器类型）。
final installedEnvironmentProvider =
    FutureProvider.autoDispose<InstalledEnvironment>(
  (ref) => ref.watch(websiteRepoProvider).installedEnvironment(),
);

/// 伪静态规则模板。
final websiteRewritesProvider =
    FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(websiteRepoProvider).rewrites(),
);

/// 证书列表（HTTPS 分页「使用已有证书」）。
final websiteCertListProvider = FutureProvider.autoDispose<List<CertItem>>(
  (ref) => ref.watch(websiteRepoProvider).certs(),
);

/// DNS 账号列表（泛域名签发证书）。
final websiteDnsListProvider = FutureProvider.autoDispose<List<DnsItem>>(
  (ref) => ref.watch(websiteRepoProvider).dnsAccounts(),
);

// ------------------------------------------------------------------ 默认设置

/// 建站默认配置（默认首页 / 停止页 / 404 页 / 默认 TLS 版本）。
final websiteDefaultConfigProvider =
    FutureProvider.autoDispose<WebsiteDefaultConfig>(
  (ref) => ref.watch(websiteRepoProvider).defaultConfig(),
);

/// 当前默认站点 id（0 表示面板内置默认页）。
final websiteDefaultSiteProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(websiteRepoProvider).defaultSite(),
);

/// 全部网站（供「默认站点」选择，一次取 1000 条足够覆盖常规场景）。
final allWebsitesProvider = FutureProvider.autoDispose<List<Website>>(
  (ref) async {
    final result =
        await ref.watch(websiteRepoProvider).list(page: 1, limit: 1000);
    return result.items;
  },
);
