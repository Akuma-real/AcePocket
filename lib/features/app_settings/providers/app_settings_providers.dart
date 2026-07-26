import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../repo/app_settings_store.dart';

/// 启动时默认打开的 tab（下次启动生效，路由 initialLocation 读取
/// [AppSettingsStore]）。
final startupTabProvider =
    NotifierProvider<StartupTabNotifier, StartupTab>(StartupTabNotifier.new);

class StartupTabNotifier extends Notifier<StartupTab> {
  @override
  StartupTab build() {
    // AppSettingsStore 在 main() 中已 init，此处可同步读取。
    return AppSettingsStore.instance.startupTab;
  }

  /// 更新启动 tab 并持久化。
  Future<void> setTab(StartupTab tab) async {
    state = tab;
    await AppSettingsStore.instance.saveStartupTab(tab);
  }
}

/// 首页实时数据轮询间隔（秒，0 = 关闭）。
final homePollIntervalProvider =
    NotifierProvider<HomePollIntervalNotifier, int>(
        HomePollIntervalNotifier.new);

class HomePollIntervalNotifier extends Notifier<int> {
  @override
  int build() {
    // AppSettingsStore 在 main() 中已 init，此处可同步读取。
    return AppSettingsStore.instance.homePollIntervalSeconds;
  }

  /// 更新轮询间隔（先 sanitize）并持久化。
  Future<void> setInterval(int seconds) async {
    final value = sanitizeHomePollInterval(seconds);
    state = value;
    await AppSettingsStore.instance.saveHomePollIntervalSeconds(value);
  }
}
