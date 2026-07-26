import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/server_store.dart';
import 'features/app_settings/repo/app_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预加载服务器配置，保证首帧即可同步读取（路由重定向依赖）。
  await ServerStore.instance.init();
  // 预加载应用偏好：GoRouter 的 initialLocation（启动 tab）依赖同步读取。
  await AppSettingsStore.instance.init();
  runApp(const ProviderScope(child: AcePanelApp()));
}
