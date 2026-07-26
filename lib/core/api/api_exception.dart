/// API 调用异常。
///
/// 由 [ApiClient] 在以下情况抛出：
/// - HTTP 状态码非 2xx（[message] 取响应 JSON 的 `msg` 字段，[statusCode] 为状态码）；
/// - 网络错误 / 超时 / 证书错误（[statusCode] 为 null，[message] 为友好提示）。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// 错误信息（面板返回的 `msg` 或本地生成的友好提示，可直接展示给用户）。
  final String message;

  /// HTTP 状态码；网络层错误时为 null。
  final int? statusCode;

  /// 是否为认证失败（令牌无效 / 过期）。
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
