import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/models/server.dart';
import '../models/connection_test.dart';

/// 服务器连接测试。
///
/// 分两步验证一份（可能尚未保存的）服务器配置。因此这里不使用全局的
/// `apiClientProvider`（它绑定当前选中的服务器），而是用待测配置临时构造
/// [ApiClient]：
///
/// 1. `GET /api/home/panel` —— 面板公开接口（源码 `internal/route/home.go`
///    标记 `Public: true`，`internal/middleware/must_login.go` 对白名单路径直接放行），
///    用于验证「地址可达 + 访问入口正确 + 对端确实是 AcePanel」；
/// 2. `GET /api/home/system_info` —— 需要 HMAC 令牌认证，
///    用于验证「令牌 ID / 令牌正确且未被 IP 白名单拦截」。
class ConnectionTestRepo {
  const ConnectionTestRepo();

  /// 执行连接测试；失败时抛出带有可读提示的 [ApiException]。
  Future<ConnectionTestResult> test(ServerConfig server) async {
    final client = ApiClient(server);

    // 第一步：连通性 + 面板识别（无需认证）。
    final PanelInfo panel;
    try {
      final data = await client.get('/home/panel');
      if (data is! Map<String, dynamic>) {
        throw const ApiException(
          '目标地址响应了非预期内容，可能不是 AcePanel 面板，'
          '或访问入口路径填写有误。',
        );
      }
      panel = PanelInfo.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 418) {
        throw ApiException(
          '面板未响应接口（HTTP ${e.statusCode}）：${e.message}\n'
          '请检查面板地址是否正确，以及是否需要在「高级选项」中填写访问入口。',
          statusCode: e.statusCode,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiException('连接面板失败：$e');
    }

    // 第二步：令牌认证校验。
    final SystemInfoBrief system;
    try {
      final data = await client.get('/home/system_info');
      system = SystemInfoBrief.fromJson(
        data is Map<String, dynamic> ? data : const <String, dynamic>{},
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        throw ApiException(
          '面板可达，但令牌验证失败：${e.message}\n'
          '请检查令牌 ID 与令牌是否正确、令牌是否已过期，'
          '以及手机时间是否准确（签名有效期 300 秒）。',
          statusCode: e.statusCode,
        );
      }
      if (e.statusCode == 403) {
        throw ApiException(
          '面板可达，但访问被拒绝：${e.message}\n'
          '请检查该令牌的 IP 白名单设置。',
          statusCode: e.statusCode,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiException('获取系统信息失败：$e');
    }

    return ConnectionTestResult(panel: panel, system: system);
  }
}
