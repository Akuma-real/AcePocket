/// 应用设置领域模型与常量。
///
/// 仅包含纯 Dart 定义（枚举 / 常量 / 工具函数），
/// 持久化逻辑见 `repo/app_settings_store.dart`。
library;

/// 启动时默认打开的底部导航 tab。
enum StartupTab {
  home('home', '/', '首页'),
  websites('websites', '/websites', '网站'),
  more('more', '/more', '更多');

  const StartupTab(this.storageValue, this.path, this.label);

  /// 持久化值。
  final String storageValue;

  /// GoRouter 路径。
  final String path;

  /// 中文标签。
  final String label;

  /// 从持久化值解析；未知 / null 回退 [StartupTab.home]。
  static StartupTab parse(String? raw) {
    for (final tab in StartupTab.values) {
      if (tab.storageValue == raw) return tab;
    }
    return StartupTab.home;
  }
}

/// 首页实时轮询间隔可选档位（秒），0 表示关闭轮询。
const List<int> kHomePollIntervalOptions = <int>[2, 3, 5, 10, 30, 0];

/// 默认轮询间隔（秒）。
const int kDefaultHomePollIntervalSeconds = 3;

/// 「关闭」档位。
const int kHomePollIntervalOff = 0;

/// 档位中文标签：0 -> '关闭'，其余 -> 'N 秒'。
String homePollIntervalLabel(int seconds) {
  if (seconds == kHomePollIntervalOff) return '关闭';
  return '$seconds 秒';
}

/// 非法值（null / 不在档位中）回退默认 [kDefaultHomePollIntervalSeconds]。
int sanitizeHomePollInterval(int? seconds) {
  if (seconds != null && kHomePollIntervalOptions.contains(seconds)) {
    return seconds;
  }
  return kDefaultHomePollIntervalSeconds;
}
