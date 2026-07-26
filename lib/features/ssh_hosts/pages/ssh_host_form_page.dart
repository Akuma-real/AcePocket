import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/ssh_host.dart';
import '../providers/ssh_hosts_providers.dart';
import '../widgets/ssh_feedback.dart';
import '../widgets/ssh_host_form.dart';

/// 新建 / 编辑 SSH 主机（`/ssh-hosts/new`、`/ssh-hosts/:id/edit`）。
///
/// 编辑时先 `GET /ssh/{id}` 拉取详情回填（面板会返回解密后的密码 / 私钥），
/// 保存成功后 `pop(true)`，由列表页刷新。
class SshHostFormPage extends ConsumerStatefulWidget {
  const SshHostFormPage({super.key, this.hostId});

  /// 为空表示新建。
  final int? hostId;

  @override
  ConsumerState<SshHostFormPage> createState() => _SshHostFormPageState();
}

class _SshHostFormPageState extends ConsumerState<SshHostFormPage> {
  bool _submitting = false;

  bool get _isEdit => widget.hostId != null;

  Future<void> _submit(SshHostDraft draft) async {
    setState(() => _submitting = true);
    try {
      final repo = ref.read(sshHostsRepoProvider);
      if (_isEdit) {
        await repo.update(widget.hostId!, draft);
      } else {
        await repo.create(draft);
      }
      if (!mounted) return;
      ref.invalidate(sshHostsProvider);
      ref.invalidate(sshHostOptionsProvider);
      if (_isEdit) ref.invalidate(sshHostDetailProvider(widget.hostId!));
      showSnack(context, _isEdit ? '主机已保存' : '主机已创建');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑主机' : '新建主机')),
      body: _isEdit ? _buildEditBody() : _buildForm(SshHostDraft.initial),
    );
  }

  Widget _buildEditBody() {
    final id = widget.hostId!;
    final detail = ref.watch(sshHostDetailProvider(id));
    return detail.when(
      loading: () => const LoadingView(message: '正在读取主机信息…'),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(sshHostDetailProvider(id)),
      ),
      data: (host) => _buildForm(host.toDraft()),
    );
  }

  Widget _buildForm(SshHostDraft initial) => SshHostForm(
        initial: initial,
        submitting: _submitting,
        submitLabel: _isEdit ? '保存' : '创建',
        onSubmit: _submit,
      );
}
