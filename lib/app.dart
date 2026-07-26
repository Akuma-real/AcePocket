import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/lifecycle/app_lifecycle.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/panel_users/two_factor.dart';
import 'features/settings/providers/appearance_providers.dart';

/// 应用根组件：MaterialApp.router + Material 3 深浅色主题 + 简体中文。
class AcePanelApp extends ConsumerStatefulWidget {
  const AcePanelApp({super.key});

  @override
  ConsumerState<AcePanelApp> createState() => _AcePanelAppState();
}

class _AcePanelAppState extends ConsumerState<AcePanelApp> {
  @override
  void initState() {
    super.initState();
    // 注册全局登录挑战处理器：面板账号开启两步验证 / 面板要求图形验证码时，
    // 任何 wsConnect（终端、容器日志、证书签发、迁移进度、面板升级…）
    // 都会自动弹出输入框。见 core/api/ws_client.dart 的 WsSessionManager。
    installWsLoginChallengeHandler();
    // 提前实例化应用生命周期状态源（core/lifecycle/app_lifecycle.dart），
    // 使 AppLifecycleListener 从应用启动起就开始监听前台 / 后台切换，
    // 供首页轮询、终端心跳、迁移重连等周期性任务在后台时暂停。
    ref.read(appForegroundProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // 主题模式由「关于」页设置并持久化（features/settings/providers/appearance_providers.dart）。
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp.router(
      title: 'AcePocket',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
