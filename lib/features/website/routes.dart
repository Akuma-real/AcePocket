import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import 'pages/website_create_page.dart';
import 'pages/website_detail_page.dart';
import 'pages/website_settings_page.dart';
import 'pages/website_stats_page.dart';

export 'pages/website_list_page.dart' show WebsiteListPage;

/// 网站管理模块路由。
///
/// - `/websites`             网站列表 —— **不在本列表中注册**：它是底部导航
///                           「网站」tab 的分支根路由，由 `core/router/router.dart`
///                           的 `StatefulShellRoute` 注册，页面通过本文件的
///                           `export` 提供（[WebsiteListPage]）。
///                           其他页面切到该 tab 请用 `context.go('/websites')`。
/// - `/websites/create`      创建网站
/// - `/websites/settings`    网站默认设置（默认首页 / 停止页 / 404 页、
///                           默认 TLS 版本、默认站点）
/// - `/websites/:id`         网站详情与配置（域名/监听、HTTPS、伪静态、
///                           反向代理、重定向、高级设置）
/// - `/websites/:id/stats`   网站访问统计（`extra` 可传入网站名称，
///                           省去一次配置请求）
///
/// 注意：`/websites/settings` 与 `/websites/create` 必须排在 `/websites/:id`
/// 之前，否则会被后者的路径参数匹配走。
final List<RouteBase> websiteRoutes = [
  GoRoute(
    path: '/websites/create',
    builder: (context, state) => const WebsiteCreatePage(),
  ),
  GoRoute(
    path: '/websites/settings',
    builder: (context, state) => const WebsiteSettingsPage(),
  ),
  GoRoute(
    path: '/websites/:id/stats',
    builder: (context, state) {
      final id = _parseId(state.pathParameters['id']);
      if (id == null) return const _InvalidRoutePage(message: '无效的网站 ID');
      final extra = state.extra;
      return WebsiteStatsPage(
        websiteId: id,
        websiteName: extra is String && extra.isNotEmpty ? extra : null,
      );
    },
  ),
  GoRoute(
    path: '/websites/:id',
    builder: (context, state) {
      final id = _parseId(state.pathParameters['id']);
      if (id == null) return const _InvalidRoutePage(message: '无效的网站 ID');
      return WebsiteDetailPage(websiteId: id);
    },
  ),
];

int? _parseId(String? raw) {
  if (raw == null) return null;
  final id = int.tryParse(raw);
  if (id == null || id <= 0) return null;
  return id;
}

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网站')),
      body: ErrorView(error: message),
    );
  }
}
