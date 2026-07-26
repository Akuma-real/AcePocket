/// 日志文件反向分页读取结果。
///
/// 对应 `GET /api/file/tail`（`internal/service/file.go` `Tail()`）：
/// `{ "lines": []string, "has_more": bool, "size": int64 }`。
///
/// 任务的 `log` 字段是**日志文件路径**（见 `internal/biz/task.go` 与
/// Web 端 `views/task/TaskView.vue` 的用法），因此任务日志通过本接口读取。
class FileTailResult {
  const FileTailResult({
    this.lines = const [],
    this.hasMore = false,
    this.size = 0,
  });

  /// 本次读取到的日志行（按时间正序，最后一行为最新）。
  final List<String> lines;

  /// 更早的内容是否还有更多。
  final bool hasMore;

  /// 文件总字节数。
  final int size;

  factory FileTailResult.fromJson(Map<String, dynamic> json) {
    return FileTailResult(
      lines: json['lines'] is List
          ? (json['lines'] as List).map((e) => '$e').toList()
          : const [],
      hasMore: json['has_more'] is bool ? json['has_more'] as bool : false,
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
    );
  }

  /// 合并为可直接展示的纯文本。
  String get text => lines.join('\n');
}
