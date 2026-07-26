import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'pages/benchmark_page.dart';
import 'pages/hosts_editor_page.dart';
import 'pages/log_clean_page.dart';
import 'pages/network_page.dart';
import 'pages/system_tools_page.dart';

/// 系统工具箱模块路由。
///
/// - `/toolbox/system`：系统工具（DNS、SWAP、时区与时间、NTP、主机名、hosts）
/// - `/toolbox/system/hosts`：/etc/hosts 全文编辑
/// - `/toolbox/logs`：日志扫描与清理
/// - `/toolbox/network`：网络连接信息
/// - `/toolbox/benchmark`：服务器跑分测试
final List<RouteBase> toolboxMiscRoutes = <RouteBase>[
  GoRoute(
    path: '/toolbox/system',
    builder: (BuildContext context, GoRouterState state) =>
        const SystemToolsPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'hosts',
        builder: (BuildContext context, GoRouterState state) =>
            const HostsEditorPage(),
      ),
    ],
  ),
  GoRoute(
    path: '/toolbox/logs',
    builder: (BuildContext context, GoRouterState state) =>
        const LogCleanPage(),
  ),
  GoRoute(
    path: '/toolbox/network',
    builder: (BuildContext context, GoRouterState state) => const NetworkPage(),
  ),
  GoRoute(
    path: '/toolbox/benchmark',
    builder: (BuildContext context, GoRouterState state) =>
        const BenchmarkPage(),
  ),
];
