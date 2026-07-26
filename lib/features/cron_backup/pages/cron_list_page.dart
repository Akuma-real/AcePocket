import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/cron.dart';
import '../providers/cron_providers.dart';
import '../widgets/cron_tile.dart';
import '../widgets/feedback.dart';
import '../widgets/no_server_view.dart';
import '../widgets/paged_list.dart';

/// 计划任务列表页（`/crons`）。
class CronListPage extends ConsumerStatefulWidget {
  const CronListPage({super.key});

  @override
  ConsumerState<CronListPage> createState() => _CronListPageState();
}

class _CronListPageState extends ConsumerState<CronListPage> {
  /// 正在切换状态的任务 id，用于禁用对应开关。
  final Set<int> _toggling = {};

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final state = ref.watch(cronListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划任务'),
        actions: [
          IconButton(
            tooltip: '备份管理',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => context.push('/backups'),
          ),
        ],
      ),
      floatingActionButton: server == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            ),
      body: server == null
          ? const NoServerView()
          : state.when(
              loading: () => const LoadingView(message: '正在加载计划任务…'),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(cronListProvider),
              ),
              data: (data) => PagedList<Cron>(
                state: data,
                onRefresh: () =>
                    ref.read(cronListProvider.notifier).refresh(),
                onLoadMore: _loadMore,
                emptyView: EmptyView(
                  icon: Icons.timer_outlined,
                  message: '还没有计划任务',
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: const Text('新建任务'),
                  ),
                ),
                itemBuilder: (context, cron, _) => CronTile(
                  cron: cron,
                  busy: _toggling.contains(cron.id),
                  onToggle: (value) => _toggle(cron, value),
                  onRun: () => _run(cron),
                  onLog: () => _viewLog(cron),
                  onEdit: () => _edit(cron),
                  onDelete: () => _delete(cron),
                ),
              ),
            ),
    );
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(cronListProvider.notifier).loadMore();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _create() async {
    final saved = await context.push<bool>('/crons/edit');
    if (saved == true) {
      await ref.read(cronListProvider.notifier).refresh();
    }
  }

  Future<void> _edit(Cron cron) async {
    final saved = await context.push<bool>('/crons/edit?id=${cron.id}');
    if (saved == true) {
      await ref.read(cronListProvider.notifier).refresh();
    }
  }

  void _viewLog(Cron cron) {
    if (cron.log.isEmpty) {
      showSnack(context, '该任务没有日志文件');
      return;
    }
    context.push(
      Uri(
        path: '/crons/log',
        queryParameters: {'path': cron.log, 'name': cron.name},
      ).toString(),
    );
  }

  void _run(Cron cron) {
    if (cron.shell.isEmpty) {
      showSnack(context, '该任务没有可执行脚本');
      return;
    }
    context.push(
      Uri(
        path: '/crons/run',
        queryParameters: {'shell': cron.shell, 'name': cron.name},
      ).toString(),
    );
  }

  Future<void> _toggle(Cron cron, bool value) async {
    setState(() => _toggling.add(cron.id));
    try {
      await ref.read(cronListProvider.notifier).setStatus(cron, value);
      if (mounted) showSnack(context, value ? '任务已启用' : '任务已停用');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _toggling.remove(cron.id));
    }
  }

  Future<void> _delete(Cron cron) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除计划任务',
      content: '确定要删除「${cron.name}」吗？任务脚本与日志文件也会一并删除，此操作不可恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(cronListProvider.notifier).delete(cron.id);
      if (mounted) showSnack(context, '已删除');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }
}
