import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/logs_providers.dart';
import '../widgets/log_tile.dart';

/// 面板日志查看（`/api/log/*`）。
///
/// 面板日志接口不支持分页，只支持「取最近 N 条」（服务端上限 1000 条），
/// 因此这里以「加载更多」逐步提升条数上限，并提供归档日期切换。
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('面板日志'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '操作日志'),
              Tab(text: '数据库'),
              Tab(text: 'HTTP'),
              Tab(text: 'SSH 登录'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PanelLogView(type: 'app'),
            _PanelLogView(type: 'db'),
            _PanelLogView(type: 'http'),
            _SshLogView(),
          ],
        ),
      ),
    );
  }
}

/// 面板文件日志（app / db / http）。
class _PanelLogView extends ConsumerStatefulWidget {
  const _PanelLogView({required this.type});

  final String type;

  @override
  ConsumerState<_PanelLogView> createState() => _PanelLogViewState();
}

class _PanelLogViewState extends ConsumerState<_PanelLogView>
    with AutomaticKeepAliveClientMixin {
  static const int _maxLimit = 1000;
  static const int _step = 200;

  String _date = '';
  int _limit = 200;

  @override
  bool get wantKeepAlive => true;

  LogQuery get _query =>
      LogQuery(type: widget.type, date: _date, limit: _limit);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final datesAsync = ref.watch(logDatesProvider(widget.type));
    final logsAsync = ref.watch(logListProvider(_query));

    final dateItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('今天')),
      ...(datesAsync.valueOrNull ?? const <String>[])
          .map((d) => DropdownMenuItem(value: d, child: Text(d))),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: dateItems.any((e) => e.value == _date) ? _date : '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '日期'),
                  items: dateItems,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _date = v;
                      _limit = 200;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(logDatesProvider(widget.type));
                  ref.invalidate(logListProvider(_query));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: logsAsync.when(
            loading: () => const LoadingView(message: '正在加载日志…'),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(logListProvider(_query)),
            ),
            data: (entries) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(logDatesProvider(widget.type));
                  ref.invalidate(logListProvider(_query));
                  try {
                    await ref.read(logListProvider(_query).future);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e is ApiException ? e.message : '刷新失败：$e',
                        ),
                      ),
                    );
                  }
                },
                child: entries.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.5,
                            child: const EmptyView(
                              message: '该日期没有日志记录',
                              icon: Icons.description_outlined,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: entries.length + 1,
                        itemBuilder: (context, index) {
                          if (index == entries.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '已显示最近 ${entries.length} 条'
                                    '（上限 $_limit 条）',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_limit < _maxLimit &&
                                      entries.length >= _limit) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => setState(() {
                                        _limit = (_limit + _step)
                                            .clamp(0, _maxLimit);
                                      }),
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text('加载更多'),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                          return LogEntryTile(entry: entries[index]);
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// SSH 登录日志。
class _SshLogView extends ConsumerStatefulWidget {
  const _SshLogView();

  @override
  ConsumerState<_SshLogView> createState() => _SshLogViewState();
}

class _SshLogViewState extends ConsumerState<_SshLogView>
    with AutomaticKeepAliveClientMixin {
  static const int _maxLimit = 1000;
  static const int _step = 200;

  int _limit = 200;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final logsAsync = ref.watch(sshLogProvider(_limit));

    return logsAsync.when(
      loading: () => const LoadingView(message: '正在读取 SSH 登录日志…'),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(sshLogProvider(_limit)),
      ),
      data: (logs) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sshLogProvider(_limit));
          try {
            await ref.read(sshLogProvider(_limit).future);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e is ApiException ? e.message : '刷新失败：$e',
                ),
              ),
            );
          }
        },
        child: logs.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: const EmptyView(
                      message: '暂无 SSH 登录记录',
                      icon: Icons.vpn_key_outlined,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: logs.length + 1,
                itemBuilder: (context, index) {
                  if (index == logs.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '已显示最近 ${logs.length} 条（上限 $_limit 条）',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_limit < _maxLimit && logs.length >= _limit) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _limit = (_limit + _step).clamp(0, _maxLimit);
                              }),
                              icon: const Icon(Icons.expand_more),
                              label: const Text('加载更多'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return SshLogTile(log: logs[index]);
                },
              ),
      ),
    );
  }
}
