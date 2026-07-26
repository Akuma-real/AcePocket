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
/// 令牌管理页需要用它的 id 过滤令牌列表，故此处不使用 autoDispose，
/// 便于跨页面复用缓存；切换服务器时 apiClientProvider 变化会自动重建。
final currentUserProvider = FutureProvider<PanelUser>(
  (ref) => ref.watch(settingRepoProvider).currentUser(),
);

/// 「关于」页聚合信息。
final aboutInfoProvider = FutureProvider.autoDispose<AboutInfo>(
  (ref) => ref.watch(settingRepoProvider).aboutInfo(),
);
