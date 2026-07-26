import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import 'pages/project_detail_page.dart';
import 'pages/project_form_page.dart';
import 'pages/project_list_page.dart';
import 'pages/template_deploy_page.dart';
import 'pages/template_detail_page.dart';
import 'pages/template_list_page.dart';

/// 项目与模板模块路由。
///
/// - `/projects`                 项目列表（systemd 托管的应用项目）
/// - `/projects/create`          新建项目
/// - `/projects/:id`             项目详情与运行状态
/// - `/projects/:id/edit`        编辑项目（完整 systemd unit 配置）
/// - `/templates`                应用模板市场（分类筛选 + 关键词搜索）
/// - `/templates/:slug`          模板详情（含 compose 内容与变量说明）
/// - `/templates/:slug/deploy`   使用模板创建 docker compose 编排
///
/// 注意：`/projects/create` 必须排在 `/projects/:id` 之前，
/// 否则 `create` 会被当作 id 匹配到详情页。
final List<RouteBase> projectTemplateRoutes = <RouteBase>[
  GoRoute(
    path: '/projects',
    builder: (BuildContext context, GoRouterState state) =>
        const ProjectListPage(),
  ),
  GoRoute(
    path: '/projects/create',
    builder: (BuildContext context, GoRouterState state) =>
        const ProjectFormPage(),
  ),
  GoRoute(
    path: '/projects/:id',
    builder: (BuildContext context, GoRouterState state) {
      final id = _parseId(state.pathParameters['id']);
      if (id == null) return const _InvalidRoutePage(message: '无效的项目 ID');
      return ProjectDetailPage(projectId: id);
    },
  ),
  GoRoute(
    path: '/projects/:id/edit',
    builder: (BuildContext context, GoRouterState state) {
      final id = _parseId(state.pathParameters['id']);
      if (id == null) return const _InvalidRoutePage(message: '无效的项目 ID');
      return ProjectFormPage(projectId: id);
    },
  ),
  GoRoute(
    path: '/templates',
    builder: (BuildContext context, GoRouterState state) =>
        const TemplateListPage(),
  ),
  GoRoute(
    path: '/templates/:slug',
    builder: (BuildContext context, GoRouterState state) {
      final slug = state.pathParameters['slug'] ?? '';
      if (slug.isEmpty) {
        return const _InvalidRoutePage(message: '无效的模板标识', title: '应用模板');
      }
      return TemplateDetailPage(slug: slug);
    },
  ),
  GoRoute(
    path: '/templates/:slug/deploy',
    builder: (BuildContext context, GoRouterState state) {
      final slug = state.pathParameters['slug'] ?? '';
      if (slug.isEmpty) {
        return const _InvalidRoutePage(message: '无效的模板标识', title: '应用模板');
      }
      return TemplateDeployPage(slug: slug);
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
  const _InvalidRoutePage({required this.message, this.title = '项目'});

  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ErrorView(error: message),
    );
  }
}
