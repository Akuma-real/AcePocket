import '../../../core/api/api_client.dart';
import '../models/paged.dart';
import '../models/ssh_file_info.dart';
import '../models/ssh_host.dart';

/// SSH 主机模块数据仓库。
///
/// 接口以面板源码 `internal/route/ssh.go` 为准：
/// - `GET    /ssh`            主机列表（分页 page/limit）
/// - `POST   /ssh`            创建主机
/// - `GET    /ssh/{id}`       主机详情（password / key 已解密）
/// - `PUT    /ssh/{id}`       更新主机
/// - `DELETE /ssh/{id}`       删除主机
/// - `GET    /ssh/{id}/file`  浏览主机文件（query: path）
/// - `POST   /ssh/{id}/mkdir` 创建主机目录（body: path）
///
/// 其中文件相关接口的 `id` 为 `0` 表示**面板本机**（见 `request.SSHFile` 注释）。
class SshHostsRepository {
  const SshHostsRepository(this._api);

  final ApiClient _api;

  /// 主机列表。
  Future<Paged<SshHost>> list({required int page, required int limit}) async {
    final data = await _api.get('/ssh', query: {'page': page, 'limit': limit});
    return Paged.fromJson(data, SshHost.fromJson);
  }

  /// 主机详情。
  Future<SshHost> get(int id) async {
    final data = await _api.get('/ssh/$id');
    if (data is! Map<String, dynamic>) {
      throw StateError('主机信息返回格式异常');
    }
    return SshHost.fromJson(data);
  }

  /// 创建主机（面板会先实际建连校验，连接失败即创建失败）。
  Future<void> create(SshHostDraft draft) =>
      _api.post('/ssh', body: draft.toJson());

  /// 更新主机（同样会先建连校验）。
  Future<void> update(int id, SshHostDraft draft) =>
      _api.put('/ssh/$id', body: draft.toJson(id: id));

  /// 删除主机。
  Future<void> delete(int id) => _api.delete('/ssh/$id');

  /// 浏览主机目录（[hostId] 为 0 表示面板本机）。
  ///
  /// 面板已按「目录在前、名称升序」排好序，这里保持服务端顺序。
  Future<List<SshFileInfo>> listFiles({
    required int hostId,
    required String path,
  }) async {
    final data = await _api.get('/ssh/$hostId/file', query: {'path': path});
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SshFileInfo.fromJson)
        .toList();
  }

  /// 创建目录（[path] 为目标目录的绝对路径，面板按 MkdirAll 处理）。
  Future<void> mkdir({required int hostId, required String path}) =>
      _api.post('/ssh/$hostId/mkdir', body: {'path': path});
}
