/// API 令牌模型。
///
/// 对应面板源码 `internal/biz/user_token.go` 的 `UserToken`：
/// - 列表 / 更新响应不含 `token` 字段（源码 `json:"-"`）；
/// - 仅创建接口（`POST /api/user_tokens`，见 `internal/service/user_token.go`
///   `Create()` 手动组装响应）会返回一次完整令牌明文。
class UserToken {
  const UserToken({
    required this.id,
    required this.userId,
    this.token,
    this.ips = const [],
    this.expiredAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;

  /// 令牌明文，仅创建成功的响应中出现一次，其余场景为 null。
  final String? token;

  /// IP 白名单（支持 CIDR），空表示不限制。
  final List<String> ips;

  final DateTime? expiredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 是否已过期。
  bool get isExpired {
    final at = expiredAt;
    if (at == null) return false;
    return at.isBefore(DateTime.now());
  }

  factory UserToken.fromJson(Map<String, dynamic> json) {
    return UserToken(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      token: json['token'] is String && (json['token'] as String).isNotEmpty
          ? json['token'] as String
          : null,
      ips: json['ips'] is List
          ? (json['ips'] as List).map((e) => '$e').toList()
          : const [],
      expiredAt: _asTime(json['expired_at']),
      createdAt: _asTime(json['created_at']),
      updatedAt: _asTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (token != null) 'token': token,
      'ips': ips,
      // 字段为本地时区实例，序列化回 UTC 以保留绝对时刻（naive 串会丢偏移）。
      'expired_at': expiredAt?.toUtc().toIso8601String(),
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _asTime(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v)?.toLocal();
    }
    return null;
  }
}
