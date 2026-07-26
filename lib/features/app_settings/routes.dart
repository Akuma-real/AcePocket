import 'package:go_router/go_router.dart';

import 'pages/app_settings_page.dart';

/// 「应用设置」模块路由。
///
/// - `/app-settings` —— 应用设置（App 本地偏好：外观 / 启动行为 / 数据刷新 / 终端 / 网络与安全）。
final List<RouteBase> appSettingsRoutes = [
  GoRoute(
    path: '/app-settings',
    builder: (context, state) => const AppSettingsPage(),
  ),
];
