import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'pages/disk_page.dart';
import 'pages/raid_page.dart';
import 'pages/smart_page.dart';

/// 磁盘工具箱模块路由。
///
/// - `/toolbox/disk`：磁盘管理（磁盘与分区、LVM、fstab 三个标签页）
/// - `/toolbox/disk/smart`：SMART 健康信息
/// - `/toolbox/disk/raid`：RAID 阵列状态
final List<RouteBase> toolboxDiskRoutes = <RouteBase>[
  GoRoute(
    path: '/toolbox/disk',
    builder: (BuildContext context, GoRouterState state) => const DiskPage(),
    routes: <RouteBase>[
      GoRoute(
        path: 'smart',
        builder: (BuildContext context, GoRouterState state) =>
            const SmartPage(),
      ),
      GoRoute(
        path: 'raid',
        builder: (BuildContext context, GoRouterState state) =>
            const RaidPage(),
      ),
    ],
  ),
];
