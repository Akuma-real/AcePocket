import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../models/firewall_models.dart';
import '../providers/security_providers.dart';
import '../widgets/firewall_dialogs.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/security_dialogs.dart';
import '../widgets/security_tiles.dart';

/// 防火墙页面：总开关 + 端口规则 / IP 规则 / 端口转发三个分页。
class FirewallPage extends ConsumerStatefulWidget {
  const FirewallPage({super.key});

  @override
  ConsumerState<FirewallPage> createState() => _FirewallPageState();
}

class _FirewallPageState extends ConsumerState<FirewallPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);
  bool _togglingFirewall = false;

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

  Future<void> _toggleFirewall(bool value) async {
    if (!value) {
      final confirmed = await showConfirmDialog(
        context,
        title: '关闭防火墙？',
        content: '关闭后服务器所有端口将不再受防火墙保护，确定继续？',
        confirmText: '关闭',
        danger: true,
      );
      if (!confirmed) return;
    }
    setState(() => _togglingFirewall = true);
    try {
      await ref.read(securityRepoProvider).updateFirewallStatus(value);
      ref.invalidate(firewallStatusProvider);
      if (!mounted) return;
      showSnack(context, value ? '防火墙已开启' : '防火墙已关闭');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _togglingFirewall = false);
    }
  }

  void _refreshCurrentTab() {
    switch (_tabController.index) {
      case 0:
        ref.invalidate(firewallRulesProvider);
      case 1:
        ref.invalidate(firewallIpRulesProvider);
      case 2:
        ref.invalidate(firewallForwardsProvider);
    }
    ref.invalidate(firewallStatusProvider);
  }

  Future<void> _create() async {
    final repo = ref.read(securityRepoProvider);
    try {
      switch (_tabController.index) {
        case 0:
          final portRule = await showFirewallRuleSheet(context);
          if (portRule == null || !mounted) return;
          await repo.createFirewallRule(
            family: portRule.family,
            protocol: portRule.protocol,
            portStart: portRule.portStart,
            portEnd: portRule.portEnd,
            address: portRule.address,
            strategy: portRule.strategy,
            direction: portRule.direction,
          );
          ref.invalidate(firewallRulesProvider);
        case 1:
          final ipRule = await showFirewallIpRuleSheet(context);
          if (ipRule == null || !mounted) return;
          await repo.createFirewallIpRule(ipRule);
          ref.invalidate(firewallIpRulesProvider);
        case 2:
          final forward = await showFirewallForwardSheet(context);
          if (forward == null || !mounted) return;
          await repo.createFirewallForward(forward);
          ref.invalidate(firewallForwardsProvider);
      }
      if (!mounted) return;
      showSnack(context, '创建成功');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  String get _fabLabel => switch (_tabController.index) {
        0 => '新建端口规则',
        1 => '新建 IP 规则',
        _ => '新建转发',
      };

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(firewallStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('防火墙'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrentTab,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'scan':
                  context.push('/firewall/scan');
                case 'export':
                  context.push('/firewall/export');
                case 'import':
                  await context.push('/firewall/import');
                  // 导入可能新增了规则，返回后刷新端口规则列表。
                  ref.invalidate(firewallRulesProvider);
                case 'security':
                  context.push('/security');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('导出端口规则')),
              PopupMenuItem(value: 'import', child: Text('导入端口规则')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'scan', child: Text('扫描感知')),
              PopupMenuItem(value: 'security', child: Text('面板安全设置')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: status.when(
              data: (running) => SettingSwitchTile(
                title: '系统防火墙',
                subtitle: running ? '运行中，规则已生效' : '已停止，所有端口未受保护',
                icon: Icons.security_outlined,
                value: running,
                busy: _togglingFirewall,
                onChanged: _toggleFirewall,
              ),
              loading: () => const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.security_outlined),
                title: Text('系统防火墙'),
                subtitle: Text('状态获取中…'),
                trailing: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('系统防火墙'),
                subtitle: Text(errorMessage(error)),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(firewallStatusProvider),
                ),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '端口规则'),
              Tab(text: 'IP 规则'),
              Tab(text: '端口转发'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PortRuleTab(),
                _IpRuleTab(),
                _ForwardTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(_fabLabel),
      ),
    );
  }
}

// --------------------------------------------------------------------- 端口规则

class _PortRuleTab extends ConsumerWidget {
  const _PortRuleTab();

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FirewallRule rule,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除端口规则？',
      content: '${FirewallLabels.protocol(rule.protocol)} ${rule.portLabel} '
          '（${FirewallLabels.direction(rule.direction)}·'
          '${FirewallLabels.strategy(rule.strategy)}）将被移除。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(securityRepoProvider).deleteFirewallRule(rule);
      ref.invalidate(firewallRulesProvider);
      if (!context.mounted) return;
      showSnack(context, '已删除');
    } catch (e) {
      if (!context.mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  void _showUsage(BuildContext context, WidgetRef ref, FirewallRule rule) {
    showPortUsageDialog(
      context,
      port: rule.portStart,
      protocol: rule.protocol == 'udp' ? 'udp' : 'tcp',
      future: ref.read(securityRepoProvider).portUsage(
            rule.portStart,
            rule.protocol == 'udp' ? 'udp' : 'tcp',
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firewallRulesProvider);
    final notifier = ref.read(firewallRulesProvider.notifier);
    final theme = Theme.of(context);

    return PagedListView<FirewallRule>(
      state: state,
      emptyMessage: '暂无端口规则',
      emptyIcon: Icons.shield_outlined,
      onRetry: () => ref.invalidate(firewallRulesProvider),
      onLoadMore: notifier.loadMore,
      onRefresh: () async {
        try {
          await notifier.refresh();
        } catch (e) {
          if (!context.mounted) return;
          showSnack(context, errorMessage(e), error: true);
        }
      },
      itemBuilder: (context, rule, index) {
        final accept = rule.strategy == 'accept';
        return ListTile(
          leading: Icon(
            rule.direction == 'in' ? Icons.login : Icons.logout,
            color: accept ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  '${FirewallLabels.protocol(rule.protocol)} ${rule.portLabel}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TagChip(
                label: FirewallLabels.strategy(rule.strategy),
                color:
                    accept ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
              if (rule.inUse) ...[
                const SizedBox(width: 6),
                TagChip(
                  label: '占用中',
                  color: theme.colorScheme.tertiary,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${FirewallLabels.direction(rule.direction)} · '
            '${FirewallLabels.family(rule.family)} · '
            '来源 ${rule.address.isEmpty ? '不限' : rule.address}',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'usage':
                  _showUsage(context, ref, rule);
                case 'delete':
                  _delete(context, ref, rule);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'usage', child: Text('查看端口占用')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------- IP 规则

class _IpRuleTab extends ConsumerWidget {
  const _IpRuleTab();

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FirewallIpRule rule,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除 IP 规则？',
      content: '${rule.address} 的'
          '${FirewallLabels.direction(rule.direction)}'
          '${FirewallLabels.strategy(rule.strategy)}规则将被移除。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(securityRepoProvider).deleteFirewallIpRule(rule);
      ref.invalidate(firewallIpRulesProvider);
      if (!context.mounted) return;
      showSnack(context, '已删除');
    } catch (e) {
      if (!context.mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firewallIpRulesProvider);
    final notifier = ref.read(firewallIpRulesProvider.notifier);
    final theme = Theme.of(context);

    return PagedListView<FirewallIpRule>(
      state: state,
      emptyMessage: '暂无 IP 规则',
      emptyIcon: Icons.block_outlined,
      onRetry: () => ref.invalidate(firewallIpRulesProvider),
      onLoadMore: notifier.loadMore,
      onRefresh: () async {
        try {
          await notifier.refresh();
        } catch (e) {
          if (!context.mounted) return;
          showSnack(context, errorMessage(e), error: true);
        }
      },
      itemBuilder: (context, rule, index) {
        final accept = rule.strategy == 'accept';
        return ListTile(
          leading: Icon(
            accept ? Icons.verified_user_outlined : Icons.block,
            color: accept ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          title: Text(rule.address.isEmpty ? '(未指定地址)' : rule.address),
          subtitle: Text(
            '${FirewallLabels.direction(rule.direction)} · '
            '${FirewallLabels.protocol(rule.protocol)} · '
            '${FirewallLabels.family(rule.family)} · '
            '${FirewallLabels.strategy(rule.strategy)}',
          ),
          trailing: IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, rule),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- 端口转发

class _ForwardTab extends ConsumerWidget {
  const _ForwardTab();

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FirewallForward forward,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除端口转发？',
      content: '${forward.port} → ${forward.targetIp}:${forward.targetPort} '
          '的转发规则将被移除。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(securityRepoProvider).deleteFirewallForward(forward);
      ref.invalidate(firewallForwardsProvider);
      if (!context.mounted) return;
      showSnack(context, '已删除');
    } catch (e) {
      if (!context.mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firewallForwardsProvider);
    final notifier = ref.read(firewallForwardsProvider.notifier);
    final theme = Theme.of(context);

    return PagedListView<FirewallForward>(
      state: state,
      emptyMessage: '暂无端口转发规则',
      emptyIcon: Icons.alt_route_outlined,
      onRetry: () => ref.invalidate(firewallForwardsProvider),
      onLoadMore: notifier.loadMore,
      onRefresh: () async {
        try {
          await notifier.refresh();
        } catch (e) {
          if (!context.mounted) return;
          showSnack(context, errorMessage(e), error: true);
        }
      },
      itemBuilder: (context, forward, index) => ListTile(
        leading: Icon(Icons.alt_route, color: theme.colorScheme.primary),
        title: Text(
          '${forward.port} → ${forward.targetIp}:${forward.targetPort}',
        ),
        subtitle: Text('协议 ${FirewallLabels.protocol(forward.protocol)}'),
        trailing: IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(context, ref, forward),
        ),
      ),
    );
  }
}
