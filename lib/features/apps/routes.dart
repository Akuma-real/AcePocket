import 'package:go_router/go_router.dart';

import 'pages/app_store_page.dart';
import 'pages/processes_page.dart';
import 'pages/systemctl_page.dart';

/// 「应用商店与系统服务」模块路由。
///
/// - `/apps`      应用商店（已安装 / 全部，安装、卸载、更新、首页显示）
/// - `/systemctl` 系统服务管理（启停、重启、重载、开机自启、清空日志）
/// - `/processes` 进程管理（列表、排序、搜索、发送信号、结束进程）
final List<RouteBase> appsRoutes = [
  GoRoute(
    path: '/apps',
    name: 'apps',
    builder: (context, state) => const AppStorePage(),
  ),
  GoRoute(
    path: '/systemctl',
    name: 'systemctl',
    builder: (context, state) => const SystemctlPage(),
  ),
  GoRoute(
    path: '/processes',
    name: 'processes',
    builder: (context, state) => const ProcessesPage(),
  ),
];
