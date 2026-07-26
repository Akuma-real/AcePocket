/// 面板基础地址（baseUrl）的公共校验。
///
/// 供服务器配置表单（features/servers/widgets/server_form.dart）与
/// 面板迁移的远程连接（features/migration）复用，保证两处校验口径一致。
library;

/// 校验面板基础地址，如 `https://1.2.3.4:8888`。
///
/// 返回 null 表示通过，否则返回面向用户的中文错误文案。
///
/// 规则：
/// - scheme 必须为 http / https，host 非空；
/// - 不允许 userinfo（`user:pass@`）、query（`?`）、fragment（`#`）；
/// - 不允许路径：`/13140` 这类纯数字段提示端口应使用冒号，
///   `/api` 前缀提示由 App 自动添加，其余路径提示填到「访问入口」；
///   仅由 `/` 组成的尾部斜杠不算路径（由 `ServerConfig.normalizedBaseUrl` 处理）；
/// - 显式端口需在 1-65535 范围内。
String? validatePanelBaseUrl(String input) {
  final v = input.trim();
  if (v.isEmpty) return '请输入面板地址';

  final uri = Uri.tryParse(v);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return '地址需以 http:// 或 https:// 开头，如 https://1.2.3.4:8888';
  }
  if (uri.userInfo.isNotEmpty) {
    return '地址不应包含用户名密码（user:pass@），认证信息请填在对应的令牌字段';
  }
  if (uri.hasQuery) {
    return '地址不应包含查询参数（? 及其后的内容），请只填协议、主机与端口';
  }
  if (uri.hasFragment) {
    return '地址不应包含 # 及其后的内容，请只填协议、主机与端口';
  }

  // 仅由斜杠构成的尾部（如 `https://a.b/`）不算路径，
  // 由 ServerConfig.normalizedBaseUrl 统一去除。
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isNotEmpty) {
    final portLike = RegExp(r'^/(\d+)$').firstMatch(path);
    if (portLike != null) {
      return '端口需要用冒号分隔，是不是想填 :${portLike.group(1)}？';
    }
    if (path == '/api' || path.startsWith('/api/')) {
      return '地址不要包含 /api，接口前缀由 App 自动添加';
    }
    return '地址不应包含路径，访问入口请填在下方的高级选项里';
  }

  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
    return '端口号超出范围，需在 1-65535 之间';
  }
  return null;
}
