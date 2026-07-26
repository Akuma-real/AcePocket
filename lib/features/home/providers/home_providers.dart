import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/server_store.dart';
import '../models/current_info.dart';
import '../models/panel_models.dart';
import '../models/runtime_models.dart';
import '../models/update_models.dart';
import '../repo/home_repo.dart';

/// 首页 Repository（依赖当前选中服务器的 ApiClient）。
final homeRepoProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

/// 面板基础信息。
final panelInfoProvider = FutureProvider.autoDispose<PanelInfo>((ref) {
  return ref.watch(homeRepoProvider).panel();
});

/// 系统信息。
final systemInfoProvider = FutureProvider.autoDispose<SystemInfo>((ref) {
  return ref.watch(homeRepoProvider).systemInfo();
});

/// 统计信息（网站 / 数据库 / 项目 / 计划任务 / 容器数量）。
final countInfoProvider = FutureProvider.autoDispose<CountInfo>((ref) {
  return ref.watch(homeRepoProvider).countInfo();
});

/// 首页展示应用。
final homeAppsProvider = FutureProvider.autoDispose<List<HomeApp>>((ref) {
  return ref.watch(homeRepoProvider).apps();
});

/// 面板健康问题。
final healthProvider = FutureProvider.autoDispose<List<HealthIssue>>((ref) {
  return ref.watch(homeRepoProvider).health();
});

/// 占用最高进程（type: cpu / memory / disk_io）。
final topProcessesProvider = FutureProvider.autoDispose
    .family<List<ProcessStat>, String>((ref, type) {
  return ref.watch(homeRepoProvider).topProcesses(type);
});

/// 面板是否有新版本。
///
/// 面板开启「离线模式」时 `/home/check_update` 返回 403，检查失败一律视为
/// 「无更新」，避免首页因非关键请求出错而打扰用户。
final panelUpdateProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.watch(homeRepoProvider).checkUpdate();
  } on ApiException {
    return false;
  }
});

/// 面板更新日志（当前版本之后的所有版本，新版本在前）。
///
/// 面板返回的顺序不保证，这里按版本号倒序整理，方便「最新版本在最上面」展示。
/// 已是最新版 / 离线模式 / 拉取失败时接口返回错误，交由页面展示。
final panelUpdateInfoProvider =
    FutureProvider.autoDispose<List<PanelVersion>>((ref) async {
  final versions = await ref.watch(homeRepoProvider).updateInfo();
  final sorted = [...versions]..sort((a, b) => _compareVersion(b.version, a.version));
  return sorted;
});

/// 语义化版本号比较（非数字段按字符串比较，缺失段按 0 处理）。
int _compareVersion(String a, String b) {
  List<String> split(String v) =>
      v.replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[.\-+]'));
  final xs = split(a);
  final ys = split(b);
  final length = xs.length > ys.length ? xs.length : ys.length;
  for (var i = 0; i < length; i++) {
    final x = i < xs.length ? xs[i] : '0';
    final y = i < ys.length ? ys[i] : '0';
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final int result;
    if (nx != null && ny != null) {
      result = nx.compareTo(ny);
    } else {
      result = x.compareTo(y);
    }
    if (result != 0) return result;
  }
  return 0;
}

/// 面板 Go 运行时信息。
final runtimeInfoProvider = FutureProvider.autoDispose<RuntimeInfo>((ref) {
  return ref.watch(homeRepoProvider).runtimeInfo();
});

/// 面板协程堆栈（按协程编号升序）。
final goroutinesProvider =
    FutureProvider.autoDispose<List<GoroutineInfo>>((ref) async {
  final list = await ref.watch(homeRepoProvider).goroutines();
  return [...list]..sort((a, b) => a.id.compareTo(b.id));
});

/// 实时监控历史窗口长度（迷你图数据点数）。
const int kRealtimeHistoryLength = 30;

/// 首页实时监控状态：最新一次采样 + 由相邻两次采样算出的速率与迷你图序列。
class RealtimeState {
  const RealtimeState({
    required this.info,
    required this.netTxRate,
    required this.netRxRate,
    required this.diskReadRate,
    required this.diskWriteRate,
    required this.cpuHistory,
    required this.memHistory,
    required this.netTxHistory,
    required this.netRxHistory,
    required this.diskReadHistory,
    required this.diskWriteHistory,
  });

  /// 最新一次 `POST /home/current` 采样。
  final CurrentInfo info;

  /// 上行速率（字节 / 秒，所有非 lo 网卡合计）。
  final double netTxRate;

  /// 下行速率（字节 / 秒）。
  final double netRxRate;

  /// 磁盘读取速率（字节 / 秒，所有磁盘合计）。
  final double diskReadRate;

  /// 磁盘写入速率（字节 / 秒）。
  final double diskWriteRate;

  /// CPU 使用率历史（0-100）。
  final List<double> cpuHistory;

  /// 内存使用率历史（0-100）。
  final List<double> memHistory;

  final List<double> netTxHistory;
  final List<double> netRxHistory;
  final List<double> diskReadHistory;
  final List<double> diskWriteHistory;
}

/// 首页实时数据轮询（3 秒一次；页面离开后自动停止）。
final homeRealtimeProvider =
    AsyncNotifierProvider.autoDispose<HomeRealtimeNotifier, RealtimeState>(
        HomeRealtimeNotifier.new);

class HomeRealtimeNotifier extends AutoDisposeAsyncNotifier<RealtimeState> {
  static const _interval = Duration(seconds: 3);

  Timer? _timer;
  bool _fetching = false;
  bool _disposed = false;

  // 上一次采样的累计值，用于差分计算速率。
  CurrentInfo? _prev;

  // 迷你图历史序列。
  final List<double> _cpuHistory = [];
  final List<double> _memHistory = [];
  final List<double> _netTxHistory = [];
  final List<double> _netRxHistory = [];
  final List<double> _diskReadHistory = [];
  final List<double> _diskWriteHistory = [];

  @override
  Future<RealtimeState> build() async {
    // 切换服务器时 apiClientProvider 变化，本 Notifier 会重建，重置全部状态。
    final repo = ref.watch(homeRepoProvider);

    _timer?.cancel();
    _prev = null;
    _cpuHistory.clear();
    _memHistory.clear();
    _netTxHistory.clear();
    _netRxHistory.clear();
    _diskReadHistory.clear();
    _diskWriteHistory.clear();

    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _timer = null;
    });

    _timer = Timer.periodic(_interval, (_) => _tick());

    final info = await repo.current();
    return _merge(info);
  }

  /// 手动立即刷新一次（下拉刷新用）。
  Future<void> refreshNow() => _tick();

  Future<void> _tick() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    try {
      final repo = ref.read(homeRepoProvider);
      final info = await repo.current();
      if (_disposed) return;
      state = AsyncData(_merge(info));
    } catch (e, st) {
      if (_disposed) return;
      // 已有数据时保留旧数据继续轮询（网络抖动不打断页面），同时把错误一并暴露，
      // 页面据此展示「刷新失败」轻提示；首次加载失败则为纯错误态，由页面展示重试。
      state = AsyncError<RealtimeState>(e, st).copyWithPrevious(state);
    } finally {
      _fetching = false;
    }
  }

  RealtimeState _merge(CurrentInfo info) {
    var netTx = 0.0;
    var netRx = 0.0;
    var diskRead = 0.0;
    var diskWrite = 0.0;

    final prev = _prev;
    if (prev != null) {
      var elapsed = _interval.inSeconds.toDouble();
      final t1 = prev.time;
      final t2 = info.time;
      if (t1 != null && t2 != null) {
        final diff = t2.difference(t1).inMilliseconds / 1000.0;
        if (diff >= 0.5) elapsed = diff;
      }
      double rate(int now, int before) {
        final delta = now - before;
        return delta <= 0 ? 0 : delta / elapsed;
      }

      netTx = rate(info.totalBytesSent, prev.totalBytesSent);
      netRx = rate(info.totalBytesRecv, prev.totalBytesRecv);
      diskRead = rate(info.totalReadBytes, prev.totalReadBytes);
      diskWrite = rate(info.totalWriteBytes, prev.totalWriteBytes);
    }
    _prev = info;

    void push(List<double> list, double value) {
      list.add(value);
      if (list.length > kRealtimeHistoryLength) list.removeAt(0);
    }

    push(_cpuHistory, info.percent.clamp(0, 100).toDouble());
    push(_memHistory, info.mem.usedPercent.clamp(0, 100).toDouble());
    if (prev != null) {
      push(_netTxHistory, netTx);
      push(_netRxHistory, netRx);
      push(_diskReadHistory, diskRead);
      push(_diskWriteHistory, diskWrite);
    }

    return RealtimeState(
      info: info,
      netTxRate: netTx,
      netRxRate: netRx,
      diskReadRate: diskRead,
      diskWriteRate: diskWrite,
      cpuHistory: List.unmodifiable(_cpuHistory),
      memHistory: List.unmodifiable(_memHistory),
      netTxHistory: List.unmodifiable(_netTxHistory),
      netRxHistory: List.unmodifiable(_netRxHistory),
      diskReadHistory: List.unmodifiable(_diskReadHistory),
      diskWriteHistory: List.unmodifiable(_diskWriteHistory),
    );
  }
}
