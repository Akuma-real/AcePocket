import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/version/panel_feature.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feature_gate.dart';
import '../models/alert_rule.dart';
import '../providers/notify_alert_providers.dart';
import '../widgets/alert_tiles.dart';
import '../widgets/form_fields.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/snack.dart';

/// 告警页 `/alerts`：告警规则与告警记录。
class AlertPage extends ConsumerStatefulWidget {
  const AlertPage({super.key});

  @override
  ConsumerState<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends ConsumerState<AlertPage>
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
    ref.invalidate(alertRulesProvider);
    ref.invalidate(alertRecordsProvider);
    ref.invalidate(allNotifyChannelsProvider);
  }

  Future<void> _createRule() async {
    await context.push('/alerts/rules/new');
    if (!mounted) return;
    try {
      await ref.read(alertRulesProvider.notifier).reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _clearRecords() async {
    final ok = await showConfirmDialog(
      context,
      title: '清空告警记录',
      content: '所有告警记录将被删除，且不可恢复。确定继续？',
      confirmText: '清空',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(notifyAlertRepoProvider).clearAlertRecords();
      if (!mounted) return;
      showSnack(context, '告警记录已清空');
      await ref.read(alertRecordsProvider.notifier).reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('告警'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
          if (_tabController.index == 1)
            IconButton(
              tooltip: '清空记录',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearRecords,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '告警规则'),
            Tab(text: '告警记录'),
          ],
        ),
      ),
      body: Column(
        children: [
          const FeatureUnsupportedBanner(feature: PanelFeature.alert),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _AlertRulesTab(),
                _AlertRecordsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _createRule,
              icon: const Icon(Icons.add),
              label: const Text('新建规则'),
            )
          : null,
    );
  }
}

// -------------------------------------------------------------------- 告警规则

class _AlertRulesTab extends ConsumerStatefulWidget {
  const _AlertRulesTab();

  @override
  ConsumerState<_AlertRulesTab> createState() => _AlertRulesTabState();
}

class _AlertRulesTabState extends ConsumerState<_AlertRulesTab> {
  int? _busyId;

  Future<void> _reloadQuietly() async {
    try {
      await ref.read(alertRulesProvider.notifier).reload();
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

  Future<void> _edit(AlertRule rule) async {
    await context.push('/alerts/rules/${rule.id}/edit');
    if (!mounted) return;
    await _reloadQuietly();
  }

  Future<void> _toggle(AlertRule rule) async {
    await _runBusy(rule.id, () async {
      await ref
          .read(notifyAlertRepoProvider)
          .updateAlertRule(rule.copyWith(enabled: !rule.enabled));
      if (mounted) showSnack(context, rule.enabled ? '规则已停用' : '规则已启用');
      await _reloadQuietly();
    });
  }

  Future<void> _delete(AlertRule rule) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除告警规则',
      content: '确定要删除「${rule.name.isEmpty ? '未命名规则' : rule.name}」吗？'
          '删除后该规则不再触发告警。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    await _runBusy(rule.id, () async {
      await ref.read(notifyAlertRepoProvider).deleteAlertRule(rule.id);
      if (mounted) showSnack(context, '已删除');
      await _reloadQuietly();
    });
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(alertRulesProvider.notifier).loadMore();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertRulesProvider);
    return NotifyPagedListView<AlertRule>(
      state: state,
      header: const InfoBanner(
        text: '面板每分钟检查一次指标，条件连续满足设定次数后触发告警，'
            '并按静默期去重；未选择通知渠道时只记录不发送。',
      ),
      onRefresh: () => ref.read(alertRulesProvider.notifier).refresh(),
      onLoadMore: _loadMore,
      onRetry: () => ref.invalidate(alertRulesProvider),
      emptyMessage: '暂无告警规则',
      emptyIcon: Icons.notifications_active_outlined,
      itemBuilder: (context, rule, index) => AlertRuleTile(
        rule: rule,
        busy: _busyId == rule.id,
        onEdit: () => _edit(rule),
        onToggle: () => _toggle(rule),
        onDelete: () => _delete(rule),
      ),
    );
  }
}

// -------------------------------------------------------------------- 告警记录

class _AlertRecordsTab extends ConsumerStatefulWidget {
  const _AlertRecordsTab();

  @override
  ConsumerState<_AlertRecordsTab> createState() => _AlertRecordsTabState();
}

class _AlertRecordsTabState extends ConsumerState<_AlertRecordsTab> {
  Future<void> _loadMore() async {
    try {
      await ref.read(alertRecordsProvider.notifier).loadMore();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertRecordsProvider);
    return NotifyPagedListView<AlertRecord>(
      state: state,
      onRefresh: () => ref.read(alertRecordsProvider.notifier).refresh(),
      onLoadMore: _loadMore,
      onRetry: () => ref.invalidate(alertRecordsProvider),
      emptyMessage: '暂无告警记录',
      emptyIcon: Icons.history_toggle_off,
      itemBuilder: (context, record, index) => AlertRecordTile(record: record),
    );
  }
}
