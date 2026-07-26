import 'package:go_router/go_router.dart';

import 'pages/server_edit_page.dart';
import 'pages/server_list_page.dart';
import 'pages/server_setup_page.dart';

/// 「服务器接入与管理」模块路由。
///
/// - `/servers/setup` —— 初次配置引导（未配置服务器时由全局重定向指向此页）；
/// - `/servers`       —— 服务器列表（切换当前 / 测试连接 / 编辑 / 删除）；
/// - `/servers/edit`  —— 添加（无参数）或编辑（`?id=<uuid>`）；
///   附加 `&advanced=1` 时自动展开高级选项（补填面板账号入口）。
///
/// 注意：`/servers/setup` 必须排在 `/servers` 之前声明，
/// 且不作为 `/servers` 的子路由，避免与 `/servers/edit` 的匹配顺序冲突。
final List<RouteBase> serversRoutes = [
  GoRoute(
    path: '/servers/setup',
    name: 'serversSetup',
    builder: (context, state) => const ServerSetupPage(),
  ),
  GoRoute(
    path: '/servers/edit',
    name: 'serversEdit',
    builder: (context, state) {
      final query = state.uri.queryParameters;
      final advanced = query['advanced'];
      return ServerEditPage(
        serverId: query['id'],
        expandAdvanced: advanced == '1' || advanced == 'true',
      );
    },
  ),
  GoRoute(
    path: '/servers',
    name: 'servers',
    builder: (context, state) => const ServerListPage(),
  ),
];
