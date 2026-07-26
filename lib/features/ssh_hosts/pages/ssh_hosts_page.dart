import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/version/panel_feature.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feature_gate.dart';
import '../models/ssh_host.dart';
import '../providers/ssh_hosts_providers.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/ssh_feedback.dart';
import '../widgets/ssh_host_tile.dart';

/// SSH 主机列表页（`/ssh-hosts`）。
///
/// 对应面板 `internal/route/ssh.go`：列表 / 新建 / 编辑 / 删除，
/// 并提供跳转终端（复用 terminal 模块的 `/terminal?ssh=<id>`）与 SFTP 文件浏览。
class SshHostsPage extends ConsumerStatefulWidget {
  const SshHostsPage({super.key});

  @override
  ConsumerState<SshHostsPage> createState() => _SshHostsPageState();
}

class _SshHostsPageState extends ConsumerState<SshHostsPage> {
  Future<void> _refresh() async {
    try {
      await ref.read(sshHostsProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  void _reload() {
    ref.invalidate(sshHostsProvider);
    ref.invalidate(sshHostOptionsProvider);
  }

  Future<void> _create() async {
    final created = await context.push<bool>('/ssh-hosts/new');
    if (created == true) _reload();
  }

  Future<void> _edit(SshHost host) async {
    final updated = await context.push<bool>('/ssh-hosts/${host.id}/edit');
    if (updated == true) _reload();
  }

  void _openTerminal(SshHost host) {
    // terminal 模块约定：`/terminal?ssh=<主机 id>&title=<标题>`
    // （见 lib/features/terminal/models/terminal_session_spec.dart）。
    final uri = Uri(
      path: '/terminal',
      queryParameters: {
        'ssh': host.id.toString(),
        'title': host.displayName,
      },
    );
    context.push(uri.toString());
  }

  void _openFiles(SshHost host) {
    context.push('/ssh-hosts/${host.id}/files');
  }

  void _openLocalFiles() {
    // 面板源码 `request.SSHFile` 约定：id 为 0 表示面板本机。
    context.push('/ssh-hosts/0/files');
  }

  Future<void> _delete(SshHost host) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除主机「${host.displayName}」？',
      content: '删除后该主机的连接信息（含密码 / 私钥）将从面板移除，不可恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(sshHostsRepoProvider).delete(host.id);
      if (!mounted) return;
      _reload();
      showSnack(context, '主机已删除');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  void _onAction(SshHost host, SshHostAction action) {
    switch (action) {
      case SshHostAction.terminal:
        _openTerminal(host);
      case SshHostAction.files:
        _openFiles(host);
      case SshHostAction.edit:
        _edit(host);
      case SshHostAction.delete:
        _delete(host);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sshHostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH 主机'),
        actions: [
          IconButton(
            tooltip: '面板本机文件',
            icon: const Icon(Icons.folder_special_outlined),
            onPressed: _openLocalFiles,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新建主机'),
      ),
      body: Column(
        children: [
          const FeatureUnsupportedBanner(feature: PanelFeature.sshHosts),
          Expanded(
            child: PagedListView<SshHost>(
              state: state,
              onRefresh: _refresh,
              onLoadMore: () => ref.read(sshHostsProvider.notifier).loadMore(),
              onRetry: _reload,
              emptyMessage: '还没有保存任何 SSH 主机',
              emptyIcon: Icons.dns_outlined,
              emptyAction: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('新建主机'),
              ),
              itemBuilder: (context, host, index) => SshHostTile(
                host: host,
                onAction: (action) => _onAction(host, action),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
