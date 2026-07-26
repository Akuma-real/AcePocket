import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/benchmark_models.dart';
import '../models/log_models.dart';
import '../models/network_models.dart';
import '../models/system_models.dart';
import '../repo/toolbox_misc_repo.dart';

/// 系统工具箱数据仓库。
final toolboxMiscRepoProvider = Provider<ToolboxMiscRepository>(
  (ref) => ToolboxMiscRepository(ref.watch(apiClientProvider)),
);

// ------------------------------------------------------------------ 系统工具

/// 系统工具箱聚合信息：并行拉取 6 个分区，单个分区失败不影响其余分区。
///
/// 全部分区都失败（通常是网络 / 认证问题）时抛出首个异常，由页面整体展示错误。
final systemToolsProvider = FutureProvider.autoDispose<SystemToolsInfo>(
  (ref) async {
    final repo = ref.watch(toolboxMiscRepoProvider);

    Future<SectionResult<T>> load<T>(Future<T> Function() task) async {
      try {
        return SectionResult<T>.data(await task());
      } catch (e) {
        return SectionResult<T>.failure(e);
      }
    }

    final results = await Future.wait(<Future<SectionResult<Object>>>[
      load<DnsInfo>(repo.dns),
      load<SwapInfo>(repo.swap),
      load<TimezoneInfo>(repo.timezone),
      load<NtpConfig>(repo.ntpServers),
      load<String>(repo.hostname),
      load<String>(repo.hosts),
    ]);

    if (results.every((r) => !r.ok)) {
      throw results.first.error!;
    }

    return SystemToolsInfo(
      dns: results[0] as SectionResult<DnsInfo>,
      swap: results[1] as SectionResult<SwapInfo>,
      timezone: results[2] as SectionResult<TimezoneInfo>,
      ntp: results[3] as SectionResult<NtpConfig>,
      hostname: results[4] as SectionResult<String>,
      hosts: results[5] as SectionResult<String>,
    );
  },
);

/// /etc/hosts 全文（hosts 编辑页单独使用，避免与聚合数据互相影响）。
final hostsContentProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(toolboxMiscRepoProvider).hosts(),
);

// ------------------------------------------------------------------ 日志清理

/// 各日志类型的扫描 / 清理状态。
///
/// 使用非 autoDispose 的 Notifier：扫描与清理都是耗时操作，
/// 用户可能在执行过程中离开页面，返回后仍应看到结果。
/// 切换服务器时（[activeServerProvider] 变化）自动重置。
final logCleanProvider =
    NotifierProvider<LogCleanNotifier, Map<String, LogScanState>>(
        LogCleanNotifier.new);

class LogCleanNotifier extends Notifier<Map<String, LogScanState>> {
  bool _disposed = false;

  @override
  Map<String, LogScanState> build() {
    // 服务器切换后结果失效。
    ref.watch(activeServerProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return {
      for (final type in kLogTypes) type.key: const LogScanState(),
    };
  }

  LogScanState stateOf(String type) => state[type] ?? const LogScanState();

  void _patch(String type, LogScanState value) {
    if (_disposed) return;
    state = {...state, type: value};
  }

  /// 扫描指定类型；异常记录到该类型的状态中，不向外抛。
  Future<void> scan(String type) async {
    final current = stateOf(type);
    if (current.busy) return;
    _patch(type, current.copyWith(scanning: true, clearError: true));
    try {
      final items = await ref.read(toolboxMiscRepoProvider).scanLogs(type);
      _patch(
        type,
        LogScanState(items: items, scanned: true),
      );
    } catch (e) {
      _patch(type, LogScanState(error: e, scanned: false));
    }
  }

  /// 扫描全部类型（并行）。
  Future<void> scanAll() async {
    await Future.wait(kLogTypes.map((t) => scan(t.key)));
  }

  /// 清理指定类型，成功返回释放的空间文案，失败抛出异常由页面提示。
  Future<String> clean(String type) async {
    final current = stateOf(type);
    if (current.busy) return '';
    _patch(type, current.copyWith(cleaning: true, clearError: true));
    try {
      final cleaned = await ref.read(toolboxMiscRepoProvider).cleanLogs(type);
      _patch(type, current.copyWith(cleaning: false));
      // 清理后重新扫描，刷新剩余占用。
      await scan(type);
      return cleaned;
    } catch (e) {
      _patch(type, current.copyWith(cleaning: false, error: e));
      rethrow;
    }
  }
}

// ------------------------------------------------------------------ 网络连接

/// 网络连接列表的筛选条件。
final networkFilterProvider =
    StateProvider.autoDispose<NetworkFilter>((ref) => const NetworkFilter());

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

/// 网络连接分页列表：首屏加载、下拉刷新、上拉加载更多。
class NetworkConnectionsNotifier
    extends AutoDisposeAsyncNotifier<PagedState<NetworkConnection>> {
  static const int pageSize = 30;

  Future<Paged<NetworkConnection>> _fetch(int page) =>
      ref.read(toolboxMiscRepoProvider).networkConnections(
            page: page,
            limit: pageSize,
            filter: ref.read(networkFilterProvider),
          );

  @override
  Future<PagedState<NetworkConnection>> build() async {
    // watch 而非 read：切换服务器时 repo 重建，列表需随之重新加载。
    ref.watch(toolboxMiscRepoProvider);
    // 筛选条件变化时重建列表。
    ref.watch(networkFilterProvider);
    final paged = await _fetch(1);
    return PagedState<NetworkConnection>(
      items: paged.items,
      total: paged.total,
      page: 1,
    );
  }

  /// 下拉刷新：重新拉取第一页。
  Future<void> refresh() async {
    final paged = await _fetch(1);
    state = AsyncData(PagedState<NetworkConnection>(
      items: paged.items,
      total: paged.total,
      page: 1,
    ));
  }

  /// 加载下一页；已到末页或正在加载时忽略。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final paged = await _fetch(nextPage);
      final merged = [...current.items, ...paged.items];
      state = AsyncData(PagedState<NetworkConnection>(
        items: merged,
        // 空页即视为到底，避免 total 与实际条数不一致时反复触发加载。
        total: paged.items.isEmpty ? merged.length : paged.total,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final networkConnectionsProvider = AsyncNotifierProvider.autoDispose<
    NetworkConnectionsNotifier,
    PagedState<NetworkConnection>>(NetworkConnectionsNotifier.new);

// ------------------------------------------------------------------ 跑分

/// 跑分控制器。
///
/// 跑分是重量级耗时操作（单项可能数十秒），使用非 autoDispose 的 Notifier，
/// 用户离开页面后任务继续、结果保留；切换服务器时重置。
final benchmarkProvider =
    NotifierProvider<BenchmarkNotifier, BenchmarkState>(BenchmarkNotifier.new);

class BenchmarkNotifier extends Notifier<BenchmarkState> {
  bool _disposed = false;
  bool _stopRequested = false;

  @override
  BenchmarkState build() {
    ref.watch(activeServerProvider);
    _disposed = false;
    _stopRequested = false;
    ref.onDispose(() => _disposed = true);
    return const BenchmarkState();
  }

  void _set(BenchmarkState value) {
    if (_disposed) return;
    state = value;
  }

  /// 请求停止：当前项目跑完后结束（面板接口不支持中断已发出的请求）。
  void stop() {
    if (!state.running) return;
    _stopRequested = true;
    _set(state.copyWith(stopping: true));
  }

  /// 跑全部项目。
  Future<void> runAll() => run(kBenchmarkTests.map((t) => t.key).toList());

  /// 按顺序跑指定项目。
  Future<void> run(List<String> keys) async {
    if (state.running || keys.isEmpty) return;
    _stopRequested = false;

    final repo = ref.read(toolboxMiscRepoProvider);
    // 本轮要重跑的项目先清掉旧成绩与旧错误。
    final cpuScores = {...state.cpuScores}
      ..removeWhere((k, _) => keys.contains(k));
    final errors = {...state.errors}..removeWhere((k, _) => keys.contains(k));

    _set(BenchmarkState(
      running: true,
      planned: keys.length,
      completed: 0,
      cpuScores: cpuScores,
      memory: keys.contains('memory') ? null : state.memory,
      disk: keys.contains('disk') ? null : state.disk,
      errors: errors,
      finishedAt: state.finishedAt,
    ));

    var completed = 0;
    for (final key in keys) {
      if (_disposed) return;
      if (_stopRequested) break;
      _set(state.copyWith(currentKey: key));
      try {
        switch (key) {
          case 'memory':
            final memory = await repo.benchmarkMemory();
            _set(state.copyWith(memory: memory));
          case 'disk':
            final disk = await repo.benchmarkDisk();
            _set(state.copyWith(disk: disk));
          default:
            final score = await repo.benchmarkCpu(key);
            _set(state.copyWith(
              cpuScores: {...state.cpuScores, key: score},
            ));
        }
      } catch (e) {
        _set(state.copyWith(
          errors: {...state.errors, key: _message(e)},
        ));
      }
      completed++;
      _set(state.copyWith(completed: completed));
    }

    _set(state.copyWith(
      running: false,
      stopping: false,
      clearCurrentKey: true,
      finishedAt: DateTime.now(),
    ));
  }

  /// 清空全部成绩。
  void reset() {
    if (state.running) return;
    _set(const BenchmarkState());
  }

  static String _message(Object error) =>
      error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}
