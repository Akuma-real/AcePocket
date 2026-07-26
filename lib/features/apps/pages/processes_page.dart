import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/process_info.dart';
import '../providers/process_providers.dart';
import '../widgets/paged_list_footer.dart';
import '../widgets/process_detail_sheet.dart';
import '../widgets/process_signal_sheet.dart';
import '../widgets/process_tile.dart';

/// 进程管理页面（/processes）。
class ProcessesPage extends ConsumerStatefulWidget {
  const ProcessesPage({super.key});

  @override
  ConsumerState<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends ConsumerState<ProcessesPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _busyPids = <int>{};
  Timer? _debounce;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(processQueryProvider).keyword;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  ProcessListNotifier get _notifier => ref.read(processListProvider.notifier);

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(processQueryProvider.notifier).setKeyword(value.trim());
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    final error = await _notifier.loadMore();
    _loadingMore = false;
    if (error != null) _toast('加载更多失败：$error', error: true);
  }

  Future<void> _run(
    int pid,
    Future<void> Function() action, {
    required String successMessage,
    bool removeFromList = false,
  }) async {
    if (_busyPids.contains(pid)) return;
    setState(() => _busyPids.add(pid));
    try {
      await action();
      if (!mounted) return;
      _toast(successMessage);
      if (removeFromList) {
        _notifier.removePid(pid);
      } else {
        await _notifier.refresh();
      }
    } catch (e) {
      _toast('操作失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busyPids.remove(pid));
    }
  }

  Future<void> _kill(ProcessInfo process) async {
    final ok = await showConfirmDialog(
      context,
      title: '结束进程',
      content: '将向 ${process.name}（PID ${process.pid}）发送 SIGKILL 强制结束该进程。\n'
          '若为系统关键进程，可能导致服务异常，确定继续吗？',
      confirmText: '结束进程',
      danger: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(processRepoProvider);
    if (repo == null) return;
    await _run(
      process.pid,
      () => repo.kill(process.pid),
      successMessage: '已结束进程 ${process.pid}',
      removeFromList: true,
    );
  }

  Future<void> _signal(ProcessInfo process) async {
    final signal = await showProcessSignalSheet(context, process: process);
    if (signal == null || !mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: '发送 ${signal.name}',
      content: '确定向 ${process.name}（PID ${process.pid}）发送 '
          '${signal.name}（${signal.description}）吗？',
      confirmText: '发送',
      danger: signal.value == 9 || signal.value == 15 || signal.value == 19,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(processRepoProvider);
    if (repo == null) return;
    await _run(
      process.pid,
      () => repo.signal(process.pid, signal.value),
      successMessage: '已向进程 ${process.pid} 发送 ${signal.name}',
      removeFromList: signal.value == 9,
    );
  }

  void _openDetail(ProcessInfo process) {
    showProcessDetailSheet(context, pid: process.pid, name: process.name);
  }

  Future<void> _pickSort() async {
    final query = ref.read(processQueryProvider);
    final selected = await showModalBottomSheet<ProcessSortField>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('排序方式', style: theme.textTheme.titleLarge),
              ),
              const Divider(height: 1),
              // Flutter 3.32+ 用 RadioGroup 管理分组值与变更回调。
              RadioGroup<String>(
                groupValue: query.sort,
                onChanged: (value) {
                  if (value == null) return;
                  Navigator.of(context).pop(
                    ProcessSortField.all.firstWhere((f) => f.key == value),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final field in ProcessSortField.all)
                      RadioListTile<String>(
                        value: field.key,
                        title: Text(field.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    ref.read(processQueryProvider.notifier).setSort(selected.key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(processQueryProvider);
    final state = ref.watch(processListProvider);
    final sortField = ProcessSortField.fromKey(query.sort);

    return Scaffold(
      appBar: AppBar(
        title: const Text('进程管理'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _notifier.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) => ref
                  .read(processQueryProvider.notifier)
                  .setKeyword(value.trim()),
              decoration: InputDecoration(
                hintText: '按进程名或 PID 搜索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          ref
                              .read(processQueryProvider.notifier)
                              .setKeyword('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text('排序：${sortField.label}'),
                  onPressed: _pickSort,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(
                    query.desc ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                  ),
                  label: Text(query.desc ? '降序' : '升序'),
                  onPressed: () =>
                      ref.read(processQueryProvider.notifier).toggleOrder(),
                ),
                const Spacer(),
                if (state.total > 0)
                  Text(
                    '共 ${state.total} 个进程',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(state)),
        ],
      ),
    );
  }

  Widget _buildList(ProcessListState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const LoadingView(message: '加载进程列表…');
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(
        error: state.error!,
        onRetry: () => _notifier.refresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _notifier.refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (state.hasMore &&
              !state.isLoadingMore &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 320) {
            _loadMore();
          }
          return false;
        },
        child: state.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const EmptyView(
                      message: '没有匹配的进程',
                      icon: Icons.memory_outlined,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: state.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return PagedListFooter(
                      hasMore: state.hasMore,
                      total: state.total,
                      emptyLabel: '共 %d 个进程',
                    );
                  }
                  final process = state.items[index];
                  return ProcessTile(
                    key: ValueKey(process.pid),
                    process: process,
                    busy: _busyPids.contains(process.pid),
                    onTap: () => _openDetail(process),
                    onKill: () => _kill(process),
                    onSignal: () => _signal(process),
                  );
                },
              ),
      ),
    );
  }
}
