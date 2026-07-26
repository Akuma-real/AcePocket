import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/firewall_models.dart';
import '../models/firewall_scan_models.dart';
import '../models/paged.dart';
import '../models/panel_setting.dart';
import '../models/ssh_service_info.dart';
import '../models/tamper_models.dart';
import '../repo/security_repo.dart';

/// 安全防护模块数据仓库。
final securityRepoProvider = Provider<SecurityRepository>(
  (ref) => SecurityRepository(ref.watch(apiClientProvider)),
);

// ------------------------------------------------------------------ 开关状态

/// 防火墙运行状态。
final firewallStatusProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(securityRepoProvider).firewallStatus(),
);

/// 「允许 Ping」状态。
final pingStatusProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(securityRepoProvider).pingStatus(),
);

/// 面板设置（面板安全设置页使用，保留原始 JSON 以便整体回传）。
final panelSettingProvider = FutureProvider.autoDispose<PanelSetting>(
  (ref) => ref.watch(securityRepoProvider).panelSetting(),
);

// ------------------------------------------------------------------ SSH

/// SSH 服务配置信息。
final sshInfoProvider = FutureProvider.autoDispose<SshServiceInfo>(
  (ref) => ref.watch(securityRepoProvider).sshInfo(),
);

/// 指定 systemd 服务的运行状态（用于 SSH 服务开关）。
final serviceStatusProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, service) => ref.watch(securityRepoProvider).serviceStatus(service),
);

// ------------------------------------------------------------------ 防篡改

/// 防篡改整体状态（支持性 / 设置 / 统计 / eBPF 检测）。
final tamperStatusProvider = FutureProvider.autoDispose<TamperStatus>(
  (ref) => ref.watch(securityRepoProvider).tamperStatus(),
);

/// 待检查保护状态的路径列表（防篡改「路径保护」分页维护）。
///
/// 不使用 autoDispose，避免切换 tab / 弹窗返回时用户输入的路径被清空；
/// 切换服务器时由页面自行清理。
final tamperCheckPathListProvider =
    StateProvider<List<String>>((ref) => const <String>[]);

/// 上述路径的保护状态（POST /tamper/check_paths），路径列表变化时自动重查。
final tamperPathCheckProvider = FutureProvider.autoDispose<TamperPathCheck>(
  (ref) {
    final paths = ref.watch(tamperCheckPathListProvider);
    if (paths.isEmpty) return Future.value(TamperPathCheck.empty);
    return ref.watch(securityRepoProvider).tamperCheckPaths(paths);
  },
);

// ------------------------------------------------------------ 防火墙规则导出

/// 用于生成导出内容的端口规则全量列表（已剔除 IP 规则，与面板导出口径一致）。
final firewallExportRulesProvider =
    FutureProvider.autoDispose<List<FirewallRule>>(
  (ref) => ref.watch(securityRepoProvider).allFirewallRules(),
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

  /// 下拉刷新：重新拉取第一页。失败时保留旧数据并抛出异常（供 SnackBar 提示）。
  Future<void> refresh() async {
    final paged = await fetch(1, pageSize);
    state = AsyncData(
      PagedState<T>(items: paged.items, total: paged.total, page: 1),
    );
  }

  /// 加载下一页；已到末页或正在加载时忽略。加载失败静默恢复（可再次触发）。
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
        // 空页即视为到底，避免 total 与实际条数不一致时反复触发「加载更多」。
        total: paged.items.isEmpty ? merged.length : paged.total,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// 防火墙端口规则列表。
class FirewallRulesNotifier extends PagedNotifier<FirewallRule> {
  @override
  Future<PagedState<FirewallRule>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<FirewallRule>> fetch(int page, int limit) =>
      ref.read(securityRepoProvider).firewallRules(page: page, limit: limit);
}

final firewallRulesProvider = AsyncNotifierProvider.autoDispose<
    FirewallRulesNotifier, PagedState<FirewallRule>>(FirewallRulesNotifier.new);

/// 防火墙 IP 规则列表。
class FirewallIpRulesNotifier extends PagedNotifier<FirewallIpRule> {
  @override
  Future<PagedState<FirewallIpRule>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<FirewallIpRule>> fetch(int page, int limit) =>
      ref.read(securityRepoProvider).firewallIpRules(page: page, limit: limit);
}

final firewallIpRulesProvider = AsyncNotifierProvider.autoDispose<
        FirewallIpRulesNotifier, PagedState<FirewallIpRule>>(
    FirewallIpRulesNotifier.new);

/// 防火墙端口转发列表。
class FirewallForwardsNotifier extends PagedNotifier<FirewallForward> {
  @override
  Future<PagedState<FirewallForward>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<FirewallForward>> fetch(int page, int limit) =>
      ref.read(securityRepoProvider).firewallForwards(page: page, limit: limit);
}

final firewallForwardsProvider = AsyncNotifierProvider.autoDispose<
        FirewallForwardsNotifier, PagedState<FirewallForward>>(
    FirewallForwardsNotifier.new);

/// 防篡改保护规则列表。
class TamperRulesNotifier extends PagedNotifier<TamperRule> {
  @override
  Future<PagedState<TamperRule>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<TamperRule>> fetch(int page, int limit) =>
      ref.read(securityRepoProvider).tamperRules(page: page, limit: limit);
}

final tamperRulesProvider = AsyncNotifierProvider.autoDispose<
    TamperRulesNotifier, PagedState<TamperRule>>(TamperRulesNotifier.new);

/// 防篡改拦截日志列表。
class TamperLogsNotifier extends PagedNotifier<TamperLog> {
  @override
  Future<PagedState<TamperLog>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    return super.build();
  }

  @override
  Future<Paged<TamperLog>> fetch(int page, int limit) =>
      ref.read(securityRepoProvider).tamperLogs(page: page, limit: limit);
}

final tamperLogsProvider = AsyncNotifierProvider.autoDispose<TamperLogsNotifier,
    PagedState<TamperLog>>(TamperLogsNotifier.new);

// ------------------------------------------------------------------ 扫描感知

/// 扫描感知设置。
final scanSettingProvider = FutureProvider.autoDispose<ScanSetting>(
  (ref) => ref.watch(securityRepoProvider).scanSetting(),
);

/// 可用网卡列表（供扫描感知设置选择监听网卡）。
final scanInterfacesProvider = FutureProvider.autoDispose<List<NetInterface>>(
  (ref) => ref.watch(securityRepoProvider).scanInterfaces(),
);

/// 扫描统计的时间范围（最近 N 天，含今天）。
final scanRangeDaysProvider = StateProvider.autoDispose<int>((ref) => 7);

/// 扫描事件列表的筛选条件。
class ScanEventFilter {
  const ScanEventFilter({this.sourceIp = '', this.port, this.location = ''});

  final String sourceIp;
  final int? port;
  final String location;

  bool get isEmpty =>
      sourceIp.isEmpty && (port == null || port == 0) && location.isEmpty;

  ScanEventFilter copyWith({
    String? sourceIp,
    int? port,
    String? location,
    bool clearPort = false,
  }) =>
      ScanEventFilter(
        sourceIp: sourceIp ?? this.sourceIp,
        port: clearPort ? null : (port ?? this.port),
        location: location ?? this.location,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanEventFilter &&
          other.sourceIp == sourceIp &&
          other.port == port &&
          other.location == location;

  @override
  int get hashCode => Object.hash(sourceIp, port, location);
}

final scanEventFilterProvider =
    StateProvider.autoDispose<ScanEventFilter>((ref) => const ScanEventFilter());

/// 把「最近 N 天」换算为面板要求的 `YYYY-MM-DD` 起止日期。
({String start, String end}) scanRangeOf(int days) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day);
  final start = end.subtract(Duration(days: days - 1));
  return (start: _formatDate(start), end: _formatDate(end));
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 扫描感知概览（汇总 + 趋势 + Top 排行），随时间范围变化自动刷新。
final scanOverviewProvider = FutureProvider.autoDispose<ScanOverview>(
  (ref) async {
    final repo = ref.watch(securityRepoProvider);
    final range = scanRangeOf(ref.watch(scanRangeDaysProvider));
    final results = await Future.wait([
      repo.scanSummary(range.start, range.end),
      repo.scanTrend(range.start, range.end),
      repo.scanTopIps(range.start, range.end),
      repo.scanTopPorts(range.start, range.end),
    ]);
    return ScanOverview(
      summary: results[0] as ScanSummary,
      trend: results[1] as List<ScanDayTrend>,
      topIps: results[2] as List<ScanSourceRank>,
      topPorts: results[3] as List<ScanPortRank>,
    );
  },
);

/// 扫描事件列表（分页，随时间范围与筛选条件变化自动刷新）。
class ScanEventsNotifier extends PagedNotifier<ScanEvent> {
  @override
  Future<PagedState<ScanEvent>> build() {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(securityRepoProvider);
    // 时间范围 / 筛选条件变化时重建列表。
    ref.watch(scanRangeDaysProvider);
    ref.watch(scanEventFilterProvider);
    return super.build();
  }

  @override
  Future<Paged<ScanEvent>> fetch(int page, int limit) {
    final range = scanRangeOf(ref.read(scanRangeDaysProvider));
    final filter = ref.read(scanEventFilterProvider);
    return ref.read(securityRepoProvider).scanEvents(
          start: range.start,
          end: range.end,
          page: page,
          limit: limit,
          sourceIp: filter.sourceIp,
          port: filter.port,
          location: filter.location,
        );
  }
}

final scanEventsProvider = AsyncNotifierProvider.autoDispose<ScanEventsNotifier,
    PagedState<ScanEvent>>(ScanEventsNotifier.new);
