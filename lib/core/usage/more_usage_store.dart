import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个入口的使用记录。
class MoreUsageRecord {
  const MoreUsageRecord({
    required this.path,
    required this.count,
    required this.lastUsedMs,
  });

  /// 入口路由 path，如 '/websites'。
  final String path;

  /// 累计点击次数。
  final int count;

  /// 最近一次点击的 epoch 毫秒。
  final int lastUsedMs;
}

/// 「更多」页入口使用记录持久化（shared_preferences）。
///
/// 使用约定：`main()` 中先 `await MoreUsageStore.instance.init()` 再 `runApp`，
/// 之后 [records] 可同步读取，供「常用置顶」分组首帧渲染。
class MoreUsageStore {
  MoreUsageStore._();

  static final MoreUsageStore instance = MoreUsageStore._();

  /// 使用记录存储键（String，存单个 JSON 对象，
  /// 形如 `{"/websites":{"c":3,"t":1700000000000}}`，c=count，t=lastUsedMs）。
  static const String storageKey = 'more_page.usage';

  Map<String, MoreUsageRecord> _records = <String, MoreUsageRecord>{};
  bool _initialized = false;

  /// 时间注入点（仅供单测固定时间）；为 null 时用 `DateTime.now()`。
  @visibleForTesting
  int Function()? nowMsForTesting;

  bool get initialized => _initialized;

  /// path -> 使用记录；返回不可变快照。未 init / 无值 / 数据损坏时为空 map。
  Map<String, MoreUsageRecord> get records =>
      Map<String, MoreUsageRecord>.unmodifiable(_records);

  /// 从本地存储加载数据到内存，应用启动时调用一次。
  /// 幂等；读失败或数据损坏静默回退为空。
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _records = _parse(prefs.getString(storageKey));
    } catch (_) {
      _records = <String, MoreUsageRecord>{};
    }
    _initialized = true;
  }

  /// 记录一次点击：次数 +1、时间更新为现在；先更内存再持久化，写失败不抛异常。
  Future<void> recordTap(String path) async {
    final nowMs =
        nowMsForTesting?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final old = _records[path];
    _records = Map<String, MoreUsageRecord>.of(_records)
      ..[path] = MoreUsageRecord(
        path: path,
        count: (old?.count ?? 0) + 1,
        lastUsedMs: nowMs,
      );
    await _persist();
  }

  /// 清空内存记录并移除存储键；失败不抛异常。
  Future<void> clear() async {
    _records = <String, MoreUsageRecord>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // 存储失败不影响当前会话的清空生效。
    }
  }

  /// 清空内存状态与 initialized 标记（仅供单测重复 init）。
  @visibleForTesting
  void resetForTesting() {
    _records = <String, MoreUsageRecord>{};
    _initialized = false;
    nowMsForTesting = null;
  }

  /// 把内存记录序列化为 JSON 写入存储；写失败不抛异常。
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = <String, Object>{
        for (final r in _records.values)
          r.path: <String, int>{'c': r.count, 't': r.lastUsedMs},
      };
      await prefs.setString(storageKey, jsonEncode(json));
    } catch (_) {
      // 存储失败不影响当前会话的记录生效。
    }
  }

  /// 解析存储的 JSON 字符串；整体非法返回空 map，单条非法静默丢弃。
  static Map<String, MoreUsageRecord> _parse(String? raw) {
    if (raw == null || raw.isEmpty) return <String, MoreUsageRecord>{};
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <String, MoreUsageRecord>{};
    }
    if (decoded is! Map<String, dynamic>) return <String, MoreUsageRecord>{};
    final result = <String, MoreUsageRecord>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final count = value['c'];
      final lastUsedMs = value['t'];
      if (count is! int || lastUsedMs is! int) continue;
      if (count < 0 || lastUsedMs < 0) continue;
      result[entry.key] = MoreUsageRecord(
        path: entry.key,
        count: count,
        lastUsedMs: lastUsedMs,
      );
    }
    return result;
  }
}

/// 纯函数：取常用入口 path 列表。
///
/// 排序：count 降序；相同按 lastUsedMs 降序；再相同按 path 升序（保证确定性）。
/// 仅统计 count > 0 的记录；符合条件的记录不足 [minCount] 个时返回空列表
/// （避免刚安装时出现只有一两个图标的空荡分组）；最多返回 [maxCount] 个。
List<String> topUsagePaths(
  Map<String, MoreUsageRecord> records, {
  int maxCount = 8,
  int minCount = 4,
}) {
  final candidates =
      records.values.where((r) => r.count > 0).toList(growable: false)
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          final byTime = b.lastUsedMs.compareTo(a.lastUsedMs);
          if (byTime != 0) return byTime;
          return a.path.compareTo(b.path);
        });
  if (candidates.length < minCount) return <String>[];
  return candidates.take(maxCount).map((r) => r.path).toList(growable: false);
}
