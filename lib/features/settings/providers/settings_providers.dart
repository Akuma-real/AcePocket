import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/panel_about.dart';
import '../models/panel_setting.dart';
import '../models/panel_user.dart';
import '../repo/setting_repo.dart';

/// 面板设置数据仓库。
final settingRepoProvider = Provider<SettingRepository>(
  (ref) => SettingRepository(ref.watch(apiClientProvider)),
);

/// 面板设置（`GET /api/setting`）。
final panelSettingProvider = FutureProvider.autoDispose<PanelSetting>(
  (ref) => ref.watch(settingRepoProvider).getSetting(),
);

/// 便签内容（`GET /api/setting/memo`）。
final panelMemoProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(settingRepoProvider).getMemo(),
);

/// 当前 API 令牌所属用户（`GET /api/user/info`）。
///
/// **必须是 autoDispose**：历史上这里是常驻 FutureProvider，一次请求失败后
/// AsyncError 会被永久缓存——令牌页的「重试」只 invalidate 了令牌列表，
/// 而列表取数又依赖本 provider 的缓存错误，于是重试与下拉刷新都不会重新发起
/// `/user/info` 请求，用户只能杀掉 App。改为 autoDispose 后离开页面即释放；
/// 页面内的重试路径另外显式 `ref.invalidate(currentUserProvider)`。
final currentUserProvider = FutureProvider.autoDispose<PanelUser>(
  (ref) => ref.watch(settingRepoProvider).currentUser(),
);

/// 「关于」页聚合信息。
final aboutInfoProvider = FutureProvider.autoDispose<AboutInfo>(
  (ref) => ref.watch(settingRepoProvider).aboutInfo(),
);
