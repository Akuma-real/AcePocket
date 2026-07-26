/// API 调用异常。
///
/// 由 [ApiClient] 在以下情况抛出：
/// - HTTP 状态码非 2xx（[message] 取响应 JSON 的 `msg` 字段，[statusCode] 为状态码）；
/// - 网络错误 / 超时 / 证书错误（[statusCode] 为 null，[message] 为友好提示）。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.panelMessage});

  /// 错误信息（面板返回的 `msg` 或本地生成的友好提示，可直接展示给用户）。
  final String message;

  /// HTTP 状态码；网络层错误时为 null。
  final int? statusCode;

  /// 面板返回的原始 `msg`（未经 401/403 等统一文案包装）。
  ///
  /// 供需要自行组织文案的调用方使用（如连接测试的定制提示）；
  /// 面板未返回 msg 时为 null。
  final String? panelMessage;

  /// 是否为认证失败（令牌无效 / 过期）。
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// 把任意异常转成可直接展示给用户的文案。
///
/// [ApiException] 取其 message；其他异常去掉 `XxxException: ` 前缀，
/// 避免向用户暴露原始英文异常类型。
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}
