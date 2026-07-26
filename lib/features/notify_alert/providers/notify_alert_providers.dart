import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../models/alert_rule.dart';
import '../models/notify_channel.dart';
import '../models/notify_setting.dart';
import '../models/paged.dart';
import '../models/webhook.dart';
import '../repo/notify_alert_repo.dart';
import 'paged_list_notifier.dart';

/// 告警与通知模块数据仓库。
final notifyAlertRepoProvider = Provider<NotifyAlertRepository>(
  (ref) => NotifyAlertRepository(ref.watch(apiClientProvider)),
);

// ------------------------------------------------------------------ 告警规则

/// 告警规则分页列表。
class AlertRulesNotifier extends PagedListNotifier<AlertRule> {
  @override
  Future<PageResult<AlertRule>> fetch(int page, int limit) =>
      ref.read(notifyAlertRepoProvider).alertRules(page: page, limit: limit);
}

final alertRulesProvider = AsyncNotifierProvider.autoDispose<AlertRulesNotifier,
    PagedState<AlertRule>>(AlertRulesNotifier.new);

/// 单条告警规则（编辑页使用）。
final alertRuleProvider =
    FutureProvider.autoDispose.family<AlertRule, int>((ref, id) {
  return ref.watch(notifyAlertRepoProvider).alertRule(id);
});

// ------------------------------------------------------------------ 告警记录

/// 告警记录分页列表。
class AlertRecordsNotifier extends PagedListNotifier<AlertRecord> {
  @override
  Future<PageResult<AlertRecord>> fetch(int page, int limit) =>
      ref.read(notifyAlertRepoProvider).alertRecords(page: page, limit: limit);
}

final alertRecordsProvider = AsyncNotifierProvider.autoDispose<
    AlertRecordsNotifier, PagedState<AlertRecord>>(AlertRecordsNotifier.new);

// ------------------------------------------------------------------ 通知渠道

/// 通知渠道分页列表。
class NotifyChannelsNotifier extends PagedListNotifier<NotifyChannel> {
  @override
  Future<PageResult<NotifyChannel>> fetch(int page, int limit) => ref
      .read(notifyAlertRepoProvider)
      .notifyChannels(page: page, limit: limit);
}

final notifyChannelsProvider = AsyncNotifierProvider.autoDispose<
    NotifyChannelsNotifier,
    PagedState<NotifyChannel>>(NotifyChannelsNotifier.new);

/// 全部通知渠道（规则表单 / 事件设置的多选数据源）。
final allNotifyChannelsProvider =
    FutureProvider.autoDispose<List<NotifyChannel>>((ref) {
  return ref.watch(notifyAlertRepoProvider).allNotifyChannels();
});

/// 单个通知渠道（编辑页使用）。
final notifyChannelProvider =
    FutureProvider.autoDispose.family<NotifyChannel, int>((ref, id) {
  return ref.watch(notifyAlertRepoProvider).notifyChannel(id);
});

/// 事件通知设置。
final notifySettingProvider = FutureProvider.autoDispose<NotifySetting>((ref) {
  return ref.watch(notifyAlertRepoProvider).notifySetting();
});

// -------------------------------------------------------------------- WebHook

/// WebHook 分页列表。
class WebhooksNotifier extends PagedListNotifier<WebHook> {
  @override
  Future<PageResult<WebHook>> fetch(int page, int limit) =>
      ref.read(notifyAlertRepoProvider).webhooks(page: page, limit: limit);
}

final webhooksProvider = AsyncNotifierProvider.autoDispose<WebhooksNotifier,
    PagedState<WebHook>>(WebhooksNotifier.new);

/// 单个 WebHook（编辑页使用）。
final webhookProvider =
    FutureProvider.autoDispose.family<WebHook, int>((ref, id) {
  return ref.watch(notifyAlertRepoProvider).webhook(id);
});

/// 当前服务器的 WebHook 回调地址前缀（`<面板地址>/webhook/`）。
///
/// 回调路由是面板根路径下的顶层路由（`internal/route/webhook.go`），
/// 不带 `/api` 前缀，也不受「访问入口」影响。
final webhookBaseUrlProvider = Provider.autoDispose<String>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null) return '';
  return '${server.normalizedBaseUrl}/webhook/';
});
