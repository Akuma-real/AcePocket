import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/runtime_models.dart';
import '../providers/home_providers.dart';
import '../widgets/goroutine_tile.dart';
import '../widgets/runtime_info_cards.dart';

/// 运行时诊断页（`/panel/runtime`）。
///
/// - `GET /home/runtime_info` —— Go 运行时与 `runtime.MemStats` 统计；
/// - `GET /home/goroutines` —— 全部协程堆栈（`service.GoroutineInfo` 列表）。
///
/// 协程堆栈为长文本，这里用等宽字体 + 可滚动容器展示，单条与整体都能复制。
class RuntimeInfoPage extends ConsumerStatefulWidget {
  const RuntimeInfoPage({super.key});

  @override
  ConsumerState<RuntimeInfoPage> createState() => _RuntimeInfoPageState();
}

class _RuntimeInfoPageState extends ConsumerState<RuntimeInfoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  /// 协程状态筛选；null 为全部。
  String? _stateFilter;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(runtimeInfoProvider);
    ref.invalidate(goroutinesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行时诊断'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '运行时'),
            Tab(text: '协程堆栈'),
          ],
        ),
      ),
      body: server == null
          ? const EmptyView(
              icon: Icons.dns_outlined,
              message: '还没有配置任何服务器',
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRuntimeTab(),
                _buildGoroutineTab(),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 运行时
  // ---------------------------------------------------------------------------

  Widget _buildRuntimeTab() {
    final state = ref.watch(runtimeInfoProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(runtimeInfoProvider);
        await ref.read(runtimeInfoProvider.future);
      },
      child: state.when(
        loading: () => _scrollFill(const LoadingView(message: '正在获取运行时信息…')),
        error: (error, _) => _scrollFill(
          ErrorView(
            error: error,
            onRetry: () => ref.invalidate(runtimeInfoProvider),
          ),
        ),
        data: (info) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          children: [RuntimeInfoCards(info: info)],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 协程堆栈
  // ---------------------------------------------------------------------------

  Widget _buildGoroutineTab() {
    final state = ref.watch(goroutinesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(goroutinesProvider);
        await ref.read(goroutinesProvider.future);
      },
      child: state.when(
        loading: () => _scrollFill(const LoadingView(message: '正在获取协程堆栈…')),
        error: (error, _) => _scrollFill(
          ErrorView(
            error: error,
            onRetry: () => ref.invalidate(goroutinesProvider),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _scrollFill(
              const EmptyView(
                icon: Icons.alt_route_rounded,
                message: '面板未返回协程信息',
              ),
            );
          }
          final states = <String, int>{};
          for (final item in list) {
            final key = item.state.isEmpty ? '未知' : item.state;
            states[key] = (states[key] ?? 0) + 1;
          }
          final filter = _stateFilter;
          final filtered = filter == null
              ? list
              : list
                  .where((e) => (e.state.isEmpty ? '未知' : e.state) == filter)
                  .toList();

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _GoroutineHeader(
                  total: list.length,
                  shown: filtered.length,
                  states: states,
                  selected: filter,
                  onSelect: (value) => setState(() => _stateFilter = value),
                  onCopyAll: () => _copyAll(list),
                  onViewRaw: () => _openRaw(list),
                );
              }
              return GoroutineTile(info: filtered[index - 1]);
            },
          );
        },
      ),
    );
  }

  Future<void> _copyAll(List<GoroutineInfo> list) async {
    await Clipboard.setData(ClipboardData(text: _rawText(list)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已复制 ${list.length} 条协程堆栈')));
  }

  void _openRaw(List<GoroutineInfo> list) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _RawStackPage(text: _rawText(list)),
      ),
    );
  }

  static String _rawText(List<GoroutineInfo> list) =>
      list.map((e) => e.raw).join('\n\n');

  Widget _scrollFill(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(child: child),
        ),
      ],
    );
  }
}

/// 协程列表头部：统计、状态筛选与整体操作。
class _GoroutineHeader extends StatelessWidget {
  const _GoroutineHeader({
    required this.total,
    required this.shown,
    required this.states,
    required this.selected,
    required this.onSelect,
    required this.onCopyAll,
    required this.onViewRaw,
  });

  final int total;
  final int shown;
  final Map<String, int> states;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onCopyAll;
  final VoidCallback onViewRaw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = states.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? '共 $total 个协程'
                      : '共 $total 个协程，当前筛选 $shown 个',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onViewRaw,
                icon: const Icon(Icons.article_outlined, size: 18),
                label: const Text('原始文本'),
              ),
              IconButton(
                tooltip: '复制全部堆栈',
                icon: const Icon(Icons.copy_all, size: 20),
                onPressed: onCopyAll,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text('全部 $total'),
                selected: selected == null,
                onSelected: (_) => onSelect(null),
              ),
              for (final entry in entries)
                ChoiceChip(
                  label: Text('${entry.key} ${entry.value}'),
                  selected: selected == entry.key,
                  onSelected: (_) => onSelect(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 全部协程堆栈的原始文本页：等宽字体，纵横皆可滚动，可整体复制。
class _RawStackPage extends StatelessWidget {
  const _RawStackPage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('协程堆栈原文'),
        actions: [
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
