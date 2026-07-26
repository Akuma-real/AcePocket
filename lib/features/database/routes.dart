import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/database_list_page.dart';
import 'pages/database_servers_page.dart';
import 'pages/database_users_page.dart';
import 'pages/elasticsearch_page.dart';
import 'pages/redis_page.dart';

/// 数据库模块路由。
///
/// - `/databases` 数据库列表（创建 / 删除 / 改密）
/// - `/databases/servers` 数据库服务器管理（本地 / 远程）
/// - `/databases/users` 数据库用户管理
/// - `/databases/redis` Redis 键值管理
/// - `/databases/elasticsearch` Elasticsearch 索引与文档管理
final List<RouteBase> databaseRoutes = <RouteBase>[
  GoRoute(
    path: '/databases',
    name: 'databases',
    builder: (BuildContext context, GoRouterState state) =>
        const DatabaseListPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'servers',
        name: 'database-servers',
        builder: (BuildContext context, GoRouterState state) =>
            const DatabaseServersPage(),
      ),
      GoRoute(
        path: 'users',
        name: 'database-users',
        builder: (BuildContext context, GoRouterState state) =>
            const DatabaseUsersPage(),
      ),
      GoRoute(
        path: 'redis',
        name: 'database-redis',
        builder: (BuildContext context, GoRouterState state) =>
            const RedisPage(),
      ),
      GoRoute(
        path: 'elasticsearch',
        name: 'database-elasticsearch',
        builder: (BuildContext context, GoRouterState state) =>
            const ElasticsearchPage(),
      ),
    ],
  ),
];
