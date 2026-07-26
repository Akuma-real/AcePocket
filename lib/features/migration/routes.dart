import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'pages/migration_page.dart';
import 'pages/migration_results_page.dart';

/// 面板迁移模块路由。
///
/// - `/migration`：迁移向导（连接 → 预检 → 选择迁移项 → 迁移中 → 完成），
///   进度通过 `WS /api/ws/migration/progress` 实时展示；
/// - `/migration/results`：迁移结果与完整日志查看。
final List<RouteBase> migrationRoutes = <RouteBase>[
  GoRoute(
    path: '/migration',
    builder: (BuildContext context, GoRouterState state) =>
        const MigrationPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'results',
        builder: (BuildContext context, GoRouterState state) =>
            const MigrationResultsPage(),
      ),
    ],
  ),
];
