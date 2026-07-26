import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/ssh_file_info.dart';
import '../models/ssh_host.dart';
import '../providers/ssh_hosts_providers.dart';
import '../widgets/sftp_file_tile.dart';
import '../widgets/sftp_path_bar.dart';
import '../widgets/ssh_feedback.dart';

/// 主机文件浏览（`/ssh-hosts/:id/files`）。
///
/// 对应面板接口 `GET /ssh/{id}/file`（浏览目录）与 `POST /ssh/{id}/mkdir`
/// （创建目录）；`id` 为 0 表示面板本机（`request.SSHFile` 的约定）。
/// 面板的 SFTP 接口只提供目录浏览与建目录，不含上传 / 下载 / 删除。
class SshSftpPage extends ConsumerStatefulWidget {
  const SshSftpPage({
    super.key,
    required this.hostId,
    this.initialPath = '/',
  });

  final int hostId;
  final String initialPath;

  @override
  ConsumerState<SshSftpPage> createState() => _SshSftpPageState();
}

class _SshSftpPageState extends ConsumerState<SshSftpPage> {
  late int _hostId = widget.hostId;
  late String _path = normalizePath(widget.initialPath);
  bool _busy = false;

  SftpQuery get _query => (hostId: _hostId, path: _path);

  String _hostLabel(List<SshHost> hosts) {
    if (_hostId == 0) return '面板本机';
    for (final host in hosts) {
      if (host.id == _hostId) return host.displayName;
    }
    return 'SSH 主机 #$_hostId';
  }

  void _navigateTo(String path) {
    final next = normalizePath(path);
    if (next == _path) return;
    setState(() => _path = next);
  }

  void _goUp() {
    if (_path == '/') return;
    _navigateTo(parentPath(_path));
  }

  void _switchHost(int hostId) {
    if (hostId == _hostId) return;
    setState(() {
      _hostId = hostId;
      _path = '/';
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(sftpListingProvider(_query));
    try {
      await ref.read(sftpListingProvider(_query).future);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _promptPath() async {
    final input = await showTextInputDialog(
      context,
      title: '跳转到目录',
      initialValue: _path,
      label: '绝对路径',
      hintText: '/opt',
      confirmText: '前往',
    );
    if (input == null) return;
    _navigateTo(input);
  }

  Future<void> _mkdir() async {
    final name = await showTextInputDialog(
      context,
      title: '新建目录',
      label: '目录名称',
      hintText: 'backup',
      helperText: '将创建在 $_path 下，支持多级（如 a/b）',
      confirmText: '创建',
    );
    if (name == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(sshHostsRepoProvider).mkdir(
            hostId: _hostId,
            path: joinPath(_path, name),
          );
      ref.invalidate(sftpListingProvider(_query));
      if (!mounted) return;
      showSnack(context, '目录已创建');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onTapFile(SshFileInfo file) {
    if (file.navigable) {
      _navigateTo(joinPath(_path, file.name));
      return;
    }
    showSftpFileInfoDialog(context, file: file, directory: _path);
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(sshHostOptionsProvider).valueOrNull ?? const [];
    final listing = ref.watch(sftpListingProvider(_query));

    return PopScope(
      canPop: _path == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hostLabel(hosts)),
              Text(
                '文件浏览',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '上级目录',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _path == '/' ? null : _goUp,
            ),
            IconButton(
              tooltip: '新建目录',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _busy ? null : _mkdir,
            ),
            PopupMenuButton<int>(
              tooltip: '切换主机',
              icon: const Icon(Icons.swap_horiz),
              onSelected: _switchHost,
              itemBuilder: (context) => [
                CheckedPopupMenuItem<int>(
                  value: 0,
                  checked: _hostId == 0,
                  child: const Text('面板本机'),
                ),
                for (final host in hosts)
                  CheckedPopupMenuItem<int>(
                    value: host.id,
                    checked: _hostId == host.id,
                    child: Text(host.displayName),
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            SftpPathBar(
              path: _path,
              onNavigate: _navigateTo,
              onEditPath: _promptPath,
            ),
            Expanded(
              child: listing.when(
                loading: () => const LoadingView(message: '正在读取目录…'),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(sftpListingProvider(_query)),
                ),
                data: _buildList,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<SshFileInfo> files) {
    if (files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: EmptyView(
                message: '当前目录为空',
                icon: Icons.folder_open_outlined,
                action: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _mkdir,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建目录'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: files.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == files.length) {
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '共 ${files.length} 项',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final file = files[index];
          return SftpFileTile(
            file: file,
            onTap: () => _onTapFile(file),
            onShowInfo: () => showSftpFileInfoDialog(
              context,
              file: file,
              directory: _path,
            ),
          );
        },
      ),
    );
  }
}
