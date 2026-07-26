import 'dart:math';

/// 一台已配置的 AcePanel 服务器。
///
/// - [baseUrl] 形如 `https://1.2.3.4:8888`，不含 `/api` 前缀、不含末尾斜杠。
/// - [tokenId] / [token]：面板「API 令牌」的 ID 与令牌值（HMAC-SHA256 签名密钥），
///   用于所有 HTTP API 请求（见 core/api/api_client.dart）。
/// - [username] / [password]：面板登录账号（可选）。仅 WebSocket 功能
///   （终端 / SSH / 日志跟踪 / 证书签发进度等）需要 —— 面板服务端明确禁止
///   HMAC 令牌用于 `/api/ws/*`，WS 只能走会话 Cookie 认证，
///   详见 core/api/ws_client.dart 顶部注释。未填写时 WS 功能不可用。
/// - [entrance]：面板「访问入口」路径（如 `/my-entrance`），未设置入口时留空。
/// - [allowSelfSigned]：允许自签名 / 无效 HTTPS 证书。
class ServerConfig {
  const ServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.tokenId,
    required this.token,
    this.allowSelfSigned = false,
    this.username = '',
    this.password = '',
    this.entrance = '',
  });

  /// 唯一 id（uuid 形式），新建时用 [ServerConfig.newId] 生成。
  final String id;

  /// 显示名称。
  final String name;

  /// 面板地址，e.g. `https://1.2.3.4:8888`（不含 /api）。
  final String baseUrl;

  /// API 令牌 ID（面板中令牌列表的数字 ID，以字符串保存）。
  final String tokenId;

  /// API 令牌（HMAC-SHA256 签名密钥）。
  final String token;

  /// 允许自签名证书。
  final bool allowSelfSigned;

  /// 面板登录用户名（仅 WebSocket 功能需要，可为空）。
  final String username;

  /// 面板登录密码（仅 WebSocket 功能需要，可为空）。
  final String password;

  /// 面板访问入口路径（如 `/entrance`），未设置时为空字符串。
  final String entrance;

  /// 去掉末尾斜杠的 baseUrl。
  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 规范化的入口路径：空字符串（未设置）或以 `/` 开头、不以 `/` 结尾。
  String get entrancePath {
    var e = entrance.trim();
    if (e.isEmpty || e == '/') return '';
    if (!e.startsWith('/')) e = '/$e';
    while (e.endsWith('/')) {
      e = e.substring(0, e.length - 1);
    }
    return e;
  }

  /// 是否已配置面板账号（WebSocket 功能可用的前提）。
  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  ServerConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? tokenId,
    String? token,
    bool? allowSelfSigned,
    String? username,
    String? password,
    String? entrance,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      tokenId: tokenId ?? this.tokenId,
      token: token ?? this.token,
      allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
      username: username ?? this.username,
      password: password ?? this.password,
      entrance: entrance ?? this.entrance,
    );
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      tokenId: json['token_id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      allowSelfSigned: json['allow_self_signed'] as bool? ?? false,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      entrance: json['entrance'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'base_url': baseUrl,
      'token_id': tokenId,
      'token': token,
      'allow_self_signed': allowSelfSigned,
      'username': username,
      'password': password,
      'entrance': entrance,
    };
  }

  /// 生成一个 UUID v4 格式的随机 id。
  static String newId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          other.id == id &&
          other.name == name &&
          other.baseUrl == baseUrl &&
          other.tokenId == tokenId &&
          other.token == token &&
          other.allowSelfSigned == allowSelfSigned &&
          other.username == username &&
          other.password == password &&
          other.entrance == entrance;

  @override
  int get hashCode => Object.hash(id, name, baseUrl, tokenId, token,
      allowSelfSigned, username, password, entrance);

  @override
  String toString() => 'ServerConfig($name, $baseUrl)';
}
