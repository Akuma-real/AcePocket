/// 面板运行时诊断模型。
///
/// 字段逐条对应 `internal/service/home.go` 的 `RuntimeInfo` / `Goroutines`
/// 两个 Handler 的响应（前者是 `runtime.MemStats` 的扁平化输出）。
library;

double _num(Object? raw) => (raw as num?)?.toDouble() ?? 0;

int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;

/// `GET /home/runtime_info` 响应：Go 运行时与内存统计。
class RuntimeInfo {
  const RuntimeInfo({
    required this.uptime,
    required this.goroutines,
    required this.goVersion,
    required this.numCpu,
    required this.numCgoCall,
    required this.memoryAlloc,
    required this.memoryTotal,
    required this.memorySys,
    required this.memoryLookups,
    required this.memoryMallocs,
    required this.memoryFrees,
    required this.heapAlloc,
    required this.heapSys,
    required this.heapIdle,
    required this.heapInuse,
    required this.heapReleased,
    required this.heapObjects,
    required this.stackInuse,
    required this.stackSys,
    required this.mspanInuse,
    required this.mspanSys,
    required this.mcacheInuse,
    required this.mcacheSys,
    required this.buckHashSys,
    required this.gcSys,
    required this.otherSys,
    required this.gcNext,
    required this.gcLast,
    required this.gcPauseTotal,
    required this.gcNum,
    required this.gcNumForced,
    required this.gcCpuFraction,
  });

  /// 面板进程运行时长（秒，`time.Since(app.StartTime).Seconds()`）。
  final double uptime;

  /// 当前协程数。
  final int goroutines;

  /// 编译面板所用的 Go 版本。
  final String goVersion;

  /// 逻辑 CPU 数。
  final int numCpu;

  /// 累计 cgo 调用次数。
  final int numCgoCall;

  /// 当前已分配且仍在使用的堆内存（`MemStats.Alloc`）。
  final int memoryAlloc;

  /// 进程启动以来累计分配的堆内存（`TotalAlloc`）。
  final int memoryTotal;

  /// 从操作系统获取的总内存（`Sys`）。
  final int memorySys;

  /// 指针查找次数（`Lookups`）。
  final int memoryLookups;

  /// 累计分配对象数（`Mallocs`）。
  final int memoryMallocs;

  /// 累计释放对象数（`Frees`）。
  final int memoryFrees;

  final int heapAlloc;
  final int heapSys;
  final int heapIdle;
  final int heapInuse;
  final int heapReleased;
  final int heapObjects;

  final int stackInuse;
  final int stackSys;
  final int mspanInuse;
  final int mspanSys;
  final int mcacheInuse;
  final int mcacheSys;
  final int buckHashSys;
  final int gcSys;
  final int otherSys;

  /// 下次 GC 的堆目标大小（`NextGC`）。
  final int gcNext;

  /// 上次 GC 结束时间（`LastGC`，unix 纳秒；从未 GC 时为 0）。
  final int gcLast;

  /// 累计 STW 暂停时长（纳秒，`PauseTotalNs`）。
  final int gcPauseTotal;

  /// 已完成的 GC 次数。
  final int gcNum;

  /// 其中强制触发的次数。
  final int gcNumForced;

  /// GC 占用的 CPU 比例（0-1）。
  final double gcCpuFraction;

  /// 当前存活对象数（分配数 - 释放数）。
  int get liveObjects {
    final live = memoryMallocs - memoryFrees;
    return live < 0 ? 0 : live;
  }

  /// 上次 GC 时间（本地时区）；从未 GC 时为 null。
  DateTime? get lastGcTime => gcLast <= 0
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(gcLast ~/ 1000).toLocal();

  factory RuntimeInfo.fromJson(Map<String, dynamic> json) {
    return RuntimeInfo(
      uptime: _num(json['uptime']),
      goroutines: _int(json['goroutines']),
      goVersion: json['go_version'] as String? ?? '',
      numCpu: _int(json['num_cpu']),
      numCgoCall: _int(json['num_cgo_call']),
      memoryAlloc: _int(json['memory_alloc']),
      memoryTotal: _int(json['memory_total']),
      memorySys: _int(json['memory_sys']),
      memoryLookups: _int(json['memory_lookups']),
      memoryMallocs: _int(json['memory_mallocs']),
      memoryFrees: _int(json['memory_frees']),
      heapAlloc: _int(json['heap_alloc']),
      heapSys: _int(json['heap_sys']),
      heapIdle: _int(json['heap_idle']),
      heapInuse: _int(json['heap_inuse']),
      heapReleased: _int(json['heap_released']),
      heapObjects: _int(json['heap_objects']),
      stackInuse: _int(json['stack_inuse']),
      stackSys: _int(json['stack_sys']),
      mspanInuse: _int(json['mspan_inuse']),
      mspanSys: _int(json['mspan_sys']),
      mcacheInuse: _int(json['mcache_inuse']),
      mcacheSys: _int(json['mcache_sys']),
      buckHashSys: _int(json['buck_hash_sys']),
      gcSys: _int(json['gc_sys']),
      otherSys: _int(json['other_sys']),
      gcNext: _int(json['gc_next']),
      gcLast: _int(json['gc_last']),
      gcPauseTotal: _int(json['gc_pause_total']),
      gcNum: _int(json['gc_num']),
      gcNumForced: _int(json['gc_num_forced']),
      gcCpuFraction: _num(json['gc_cpu_fraction']),
    );
  }
}

/// `GET /home/goroutines` 响应中的一项（service.GoroutineInfo）。
class GoroutineInfo {
  const GoroutineInfo({
    required this.id,
    required this.state,
    required this.stack,
  });

  /// 协程编号（`goroutine <id> [state]:` 中的 id）。
  final int id;

  /// 协程状态，如 `running`、`IO wait`、`chan receive`、`select`。
  final String state;

  /// 堆栈正文（多行，制表符缩进）。
  final String stack;

  /// 堆栈首行（最内层调用），用于列表折叠时的摘要。
  String get topFrame {
    for (final line in stack.split('\n')) {
      final text = line.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// 还原成 `go tool` 风格的完整文本，便于复制。
  String get raw => 'goroutine $id [$state]:\n$stack';

  factory GoroutineInfo.fromJson(Map<String, dynamic> json) {
    return GoroutineInfo(
      id: _int(json['id']),
      state: json['state'] as String? ?? '',
      stack: json['stack'] as String? ?? '',
    );
  }
}
