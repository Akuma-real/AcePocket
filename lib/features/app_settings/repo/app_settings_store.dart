import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// 应用设置持久化（shared_preferences）。
///
/// 使用约定：`main()` 中先 `await AppSettingsStore.instance.init()` 再 `runApp`，
/// 之后 [startupTab] / [homePollIntervalSeconds] 可同步读取，
/// 保证 GoRouter 的 initialLocation 首帧即有数据。
class AppSettingsStore {
  AppSettingsStore._();

  static final AppSettingsStore instance = AppSettingsStore._();

  /// 启动 tab 存储键（String，存 [StartupTab.storageValue]）。
  static const String startupTabKey = 'app_settings.startup_tab';

  /// 首页轮询间隔存储键（int，秒）。
  static const String homePollIntervalKey =
      'app_settings.home_poll_interval_seconds';

  StartupTab _startupTab = StartupTab.home;
  int _homePollIntervalSeconds = kDefaultHomePollIntervalSeconds;
  bool _initialized = false;

  bool get initialized => _initialized;

  /// 启动时默认打开的 tab；未 init / 无值 / 非法值时为 [StartupTab.home]。
  StartupTab get startupTab => _startupTab;

  /// 首页轮询间隔（秒，0 = 关闭）；未 init / 无值 / 非法值时为
  /// [kDefaultHomePollIntervalSeconds]。
  int get homePollIntervalSeconds => _homePollIntervalSeconds;

  /// 从本地存储加载数据到内存，应用启动时调用一次。幂等；读失败静默回退默认值。
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _startupTab = StartupTab.parse(prefs.getString(startupTabKey));
      _homePollIntervalSeconds =
          sanitizeHomePollInterval(prefs.getInt(homePollIntervalKey));
    } catch (_) {
      _startupTab = StartupTab.home;
      _homePollIntervalSeconds = kDefaultHomePollIntervalSeconds;
    }
    _initialized = true;
  }

  /// 更新启动 tab（内存 + 持久化）；写失败不抛异常。
  Future<void> saveStartupTab(StartupTab tab) async {
    _startupTab = tab;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(startupTabKey, tab.storageValue);
    } catch (_) {
      // 存储失败不影响当前会话的设置生效。
    }
  }

  /// 更新首页轮询间隔（先 sanitize，再更新内存并持久化）；写失败不抛异常。
  Future<void> saveHomePollIntervalSeconds(int seconds) async {
    final value = sanitizeHomePollInterval(seconds);
    _homePollIntervalSeconds = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(homePollIntervalKey, value);
    } catch (_) {
      // 存储失败不影响当前会话的设置生效。
    }
  }

  /// 清空内存状态与 initialized 标记（仅供单测重复 init）。
  @visibleForTesting
  void resetForTesting() {
    _startupTab = StartupTab.home;
    _homePollIntervalSeconds = kDefaultHomePollIntervalSeconds;
    _initialized = false;
  }
}
