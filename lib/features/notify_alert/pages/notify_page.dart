import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/version/panel_feature.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_gate.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/notify_channel.dart';
import '../models/notify_setting.dart';
import '../providers/notify_alert_providers.dart';
import '../widgets/channel_selector.dart';
import '../widgets/form_fields.dart';
import '../widgets/notify_channel_tile.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/snack.dart';

/// 通知页 `/notify`：通知渠道管理与系统事件通知设置。
class NotifyPage extends ConsumerStatefulWidget {
  const NotifyPage({super.key});

  @override
  ConsumerState<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends ConsumerState<NotifyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _refreshAll() {
    ref.invalidate(notifyChannelsProvider);
    ref.invalidate(allNotifyChannelsProvider);
    ref.invalidate(notifySettingProvider);
  }

  Future<void> _createChannel() async {
    await context.push('/notify/channels/new');
    if (!mounted) return;
    ref.invalidate(allNotifyChannelsProvider);
    try {
      await ref.read(notifyChannelsProvider.notifier).reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '通知渠道'),
            Tab(text: '事件通知'),
          ],
        ),
      ),
      body: Column(
        children: [
          const FeatureUnsupportedBanner(feature: PanelFeature.notify),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ChannelsTab(),
                _EventSettingTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _createChannel,
              icon: const Icon(Icons.add),
              label: const Text('新建渠道'),
            )
          : null,
    );
  }
}

// -------------------------------------------------------------------- 通知渠道

class _ChannelsTab extends ConsumerStatefulWidget {
  const _ChannelsTab();

  @override
  ConsumerState<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends ConsumerState<_ChannelsTab> {
  int? _busyId;

  Future<void> _reloadQuietly() async {
    ref.invalidate(allNotifyChannelsProvider);
    try {
      await ref.read(notifyChannelsProvider.notifier).reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _runBusy(int id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(NotifyChannel channel) async {
    await context.push('/notify/channels/${channel.id}/edit');
    if (!mounted) return;
    await _reloadQuietly();
  }

  Future<void> _toggle(NotifyChannel channel) async {
    await _runBusy(channel.id, () async {
      await ref
          .read(notifyAlertRepoProvider)
          .updateNotifyChannel(channel.copyWith(enabled: !channel.enabled));
      if (mounted) {
        showSnack(context, channel.enabled ? '渠道已停用' : '渠道已启用');
      }
      await _reloadQuietly();
    });
  }

  Future<void> _test(NotifyChannel channel) async {
    await _runBusy(channel.id, () async {
      await ref.read(notifyAlertRepoProvider).testNotifyChannel(channel.id);
      if (mounted) showSnack(context, '测试通知已发送，请到接收端确认');
    });
  }

  Future<void> _delete(NotifyChannel channel) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除通知渠道',
      content: '确定要删除「${channel.name.isEmpty ? '未命名渠道' : channel.name}」吗？'
          '引用该渠道的告警规则与事件通知将不再向其发送。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    await _runBusy(channel.id, () async {
      await ref.read(notifyAlertRepoProvider).deleteNotifyChannel(channel.id);
      if (mounted) showSnack(context, '已删除');
      ref.invalidate(notifySettingProvider);
      await _reloadQuietly();
    });
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(notifyChannelsProvider.notifier).loadMore();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notifyChannelsProvider);
    return NotifyPagedListView<NotifyChannel>(
      state: state,
      header: const InfoBanner(
        text: '通知渠道用于发送告警与系统事件通知。渠道配置（含密码）由面板加密存储，'
            '保存后可用「发送测试通知」验证是否可达。',
      ),
      onRefresh: () => ref.read(notifyChannelsProvider.notifier).refresh(),
      onLoadMore: _loadMore,
      onRetry: () => ref.invalidate(notifyChannelsProvider),
      emptyMessage: '暂无通知渠道',
      emptyIcon: Icons.mark_email_unread_outlined,
      itemBuilder: (context, channel, index) => NotifyChannelTile(
        channel: channel,
        busy: _busyId == channel.id,
        onEdit: () => _edit(channel),
        onToggle: () => _toggle(channel),
        onTest: () => _test(channel),
        onDelete: () => _delete(channel),
      ),
    );
  }
}

// -------------------------------------------------------------------- 事件通知

class _EventSettingTab extends ConsumerStatefulWidget {
  const _EventSettingTab();

  @override
  ConsumerState<_EventSettingTab> createState() => _EventSettingTabState();
}

class _EventSettingTabState extends ConsumerState<_EventSettingTab> {
  /// 本地草稿；为 null 表示尚未加载或已与服务端同步。
  NotifySetting? _draft;
  bool _saving = false;

  Future<void> _refresh() async {
    setState(() => _draft = null);
    ref.invalidate(notifySettingProvider);
    ref.invalidate(allNotifyChannelsProvider);
    await ref.read(notifySettingProvider.future);
  }

  void _toggleEvent(String event, bool selected, NotifySetting current) {
    final events = List<String>.from(current.events);
    if (selected) {
      if (!events.contains(event)) events.add(event);
    } else {
      events.remove(event);
    }
    setState(() => _draft = current.copyWith(events: events));
  }

  Future<void> _save(NotifySetting setting) async {
    setState(() => _saving = true);
    try {
      await ref.read(notifyAlertRepoProvider).updateNotifySetting(setting);
      if (!mounted) return;
      setState(() => _draft = null);
      ref.invalidate(notifySettingProvider);
      showSnack(context, '事件通知设置已保存');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notifySettingProvider);

    if (!async.hasValue) {
      if (async.hasError) {
        return ErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(notifySettingProvider),
        );
      }
      return const LoadingView();
    }

    final setting = _draft ?? async.requireValue;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const InfoBanner(
            text: '勾选需要接收的系统事件，并选择接收通知的渠道。'
                '未选择渠道时不会发送任何事件通知。',
          ),
          SectionCard(
            title: '订阅事件',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final event in kNotifyEvents)
                  CheckboxListTile(
                    value: setting.events.contains(event.value),
                    onChanged: (value) =>
                        _toggleEvent(event.value, value ?? false, setting),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(event.label),
                    subtitle: Text(event.description),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: '接收渠道',
            child: ChannelSelector(
              selected: setting.channels,
              onChanged: (channels) => setState(
                () => _draft = setting.copyWith(channels: channels),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(setting),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存设置'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '已选 ${setting.events.length} 个事件 · ${setting.channels.length} 个渠道',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
