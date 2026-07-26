import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'pages/firewall_export_page.dart';
import 'pages/firewall_import_page.dart';
import 'pages/firewall_page.dart';
import 'pages/firewall_scan_page.dart';
import 'pages/panel_security_page.dart';
import 'pages/ssh_service_page.dart';
import 'pages/tamper_page.dart';

/// 安全防护模块路由。
///
/// - `/firewall`：防火墙（总开关 + 端口规则 / IP 规则 / 端口转发）
/// - `/firewall/scan`：扫描感知（设置、统计与扫描事件）
/// - `/firewall/export`：导出端口规则（CSV 文本 / 面板 xlsx 文件）
/// - `/firewall/import`：导入端口规则（上传 xlsx / 粘贴表格文本）
/// - `/security`：面板安全设置（安全入口、端口、登录安全、访问白名单、Ping）
/// - `/security/ssh`：SSH 服务管理（服务开关、端口、登录方式、root 凭据）
/// - `/security/tamper`：防篡改（状态与设置、保护规则、拦截日志、路径保护）
final List<RouteBase> securityRoutes = <RouteBase>[
  GoRoute(
    path: '/firewall',
    builder: (BuildContext context, GoRouterState state) =>
        const FirewallPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'scan',
        builder: (BuildContext context, GoRouterState state) =>
            const FirewallScanPage(),
      ),
      GoRoute(
        path: 'export',
        builder: (BuildContext context, GoRouterState state) =>
            const FirewallExportPage(),
      ),
      GoRoute(
        path: 'import',
        builder: (BuildContext context, GoRouterState state) =>
            const FirewallImportPage(),
      ),
    ],
  ),
  GoRoute(
    path: '/security',
    builder: (BuildContext context, GoRouterState state) =>
        const PanelSecurityPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'ssh',
        builder: (BuildContext context, GoRouterState state) =>
            const SshServicePage(),
      ),
      GoRoute(
        path: 'tamper',
        builder: (BuildContext context, GoRouterState state) =>
            const TamperPage(),
      ),
    ],
  ),
];
