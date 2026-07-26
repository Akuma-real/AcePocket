/// 后台任务模型。
///
/// 对应面板源码 `internal/biz/task.go` 的 `Task`：
/// `{ id, name, status, log, created_at, updated_at }`
/// （`key` / `shell` / `cancel_shell` 为 `json:"-"`，响应中不含）。
class TaskItem {
  const TaskItem({
    required this.id,
    this.name = '',
    this.status = TaskItem.statusWaiting,
    this.log = '',
    this.createdAt,
    this.updatedAt,
  });

  /// 任务状态常量（源码 `TaskStatus`）。
  static const statusWaiting = 'waiting';
  static const statusRunning = 'running';
  static const statusFinished = 'finished';
  static const statusFailed = 'failed';
  static const statusCanceled = 'canceled';

  final int id;
  final String name;
  final String status;
  final String log;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 是否处于可取消的活动状态（等待中 / 运行中）。
  bool get isActive => status == statusWaiting || status == statusRunning;

  /// 状态的中文描述。
  String get statusLabel {
    switch (status) {
      case statusWaiting:
        return '等待中';
      case statusRunning:
        return '运行中';
      case statusFinished:
        return '已完成';
      case statusFailed:
        return '失败';
      case statusCanceled:
        return '已取消';
      default:
        return status;
    }
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? statusWaiting,
      log: json['log'] as String? ?? '',
      createdAt: _asTime(json['created_at']),
      updatedAt: _asTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'log': log,
      // 字段为本地时区实例，序列化回 UTC 以保留绝对时刻（naive 串会丢偏移）。
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static DateTime? _asTime(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v)?.toLocal();
    }
    return null;
  }
}
