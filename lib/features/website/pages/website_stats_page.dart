import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/website_stat.dart';
import '../providers/website_providers.dart';
import '../providers/website_stat_providers.dart';
import '../widgets/formatters.dart';
import '../widgets/paged_stat_list.dart';
import '../widgets/snack.dart';
import '../widgets/stat_widgets.dart';

/// 网站统计页 `/websites/:id/stats`。
///
/// 面板统计接口是全站维度的，按网站名称（`sites` 参数）过滤，
/// 因此进入本页需要网站名称：由列表 / 详情页通过 `extra` 传入，
/// 未传入时回退到 `GET /api/website/{id}` 读取名称。
class WebsiteStatsPage extends ConsumerStatefulWidget {
  const WebsiteStatsPage({
    super.key,
    required this.websiteId,
    this.websiteName,
  });

  final int websiteId;
  final String? websiteName;

  @override
  ConsumerState<WebsiteStatsPage> createState() => _WebsiteStatsPageState();
}

class _WebsiteStatsPageState extends ConsumerState<WebsiteStatsPage> {
  StatDateRange _range = StatDateRange.today();
  int _status = 0;
  int _threshold = 0;
  String _geoGroupBy = 'country';
  String _geoCountry = '';

  static const _tabs = [
    '概览',
    'URI',
    '慢请求',
    'IP',
    '地区',
    '蜘蛛',
    '客户端',
    '错误',
  ];

  void _setRange(StatDateRange range) {
    if (_range == range) return;
    setState(() => _range = range);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6)),
        end: DateTime(now.year, now.month, now.day),
      ),
    );
    if (picked == null || !mounted) return;
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    _setRange(StatDateRange(
      start: fmt(picked.start),
      end: fmt(picked.end),
      label: '自定义',
    ));
  }

  void _refreshAll(StatQuery base, StatQuery slow, StatQuery errors,
      StatQuery geo) {
    ref.invalidate(statOverviewProvider(base));
    ref.invalidate(statRealtimeProvider);
    ref.invalidate(statUrisProvider(base));
    ref.invalidate(statIpsProvider(base));
    ref.invalidate(statSpidersProvider(base));
    ref.invalidate(statClientsProvider(base));
    ref.invalidate(statSlowUrisProvider(slow));
    ref.invalidate(statErrorsProvider(errors));
    ref.invalidate(statGeosProvider(geo));
  }

  Future<void> _openSetting() async {
    final StatSetting current;
    try {
      current = await ref.read(statSettingProvider.future);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      return;
    }
    if (!mounted) return;

    final daysController = TextEditingController(text: '${current.days}');
    var bodyEnabled = current.bodyEnabled;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('统计设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '数据保留天数',
                  helperText: '1 - 365',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('记录请求体'),
                subtitle: const Text('错误日志中保存请求体内容'),
                value: bodyEnabled,
                onChanged: (v) => setDialogState(() => bodyEnabled = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final days = int.tryParse(daysController.text.trim()) ?? current.days;
    daysController.dispose();
    if (saved != true || !mounted) return;

    if (days < 1 || days > 365) {
      showSnack(context, '保留天数需在 1 - 365 之间', error: true);
      return;
    }
    try {
      await ref.read(websiteStatRepoProvider).saveSetting(
            current.copyWith(days: days, bodyEnabled: bodyEnabled),
          );
      if (!mounted) return;
      ref.invalidate(statSettingProvider);
      showSnack(context, '统计设置已保存');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _clearStats(
      StatQuery base, StatQuery slow, StatQuery errors, StatQuery geo) async {
    final ok = await showConfirmDialog(
      context,
      title: '清空统计数据',
      content: '将清空面板中所有网站的统计数据（不仅是当前网站），且不可恢复。确定继续吗？',
      confirmText: '清空',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(websiteStatRepoProvider).clear();
      if (!mounted) return;
      showSnack(context, '统计数据已清空');
      _refreshAll(base, slow, errors, geo);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 解析网站名称：优先使用路由传入，其次读取网站配置。
    final passedName = widget.websiteName?.trim() ?? '';
    if (passedName.isEmpty) {
      final settingAsync = ref.watch(websiteSettingProvider(widget.websiteId));
      return settingAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('网站统计')),
          body: const LoadingView(message: '正在加载网站信息…'),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('网站统计')),
          body: ErrorView(
            error: error,
            onRetry: () =>
                ref.invalidate(websiteSettingProvider(widget.websiteId)),
          ),
        ),
        data: (setting) => _buildScaffold(setting.name),
      );
    }
    return _buildScaffold(passedName);
  }

  Widget _buildScaffold(String siteName) {
    final theme = Theme.of(context);
    final base = StatQuery(range: _range, sites: siteName);
    final slow = base.copyWith(threshold: _threshold);
    final errors = base.copyWith(status: _status);
    final geo = base.copyWith(groupBy: _geoGroupBy, country: _geoCountry);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(siteName),
              Text(
                '${_range.label} · ${_range.start}'
                '${_range.isSingleDay ? '' : ' ~ ${_range.end}'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: '时间范围',
              icon: const Icon(Icons.date_range),
              onSelected: (value) {
                switch (value) {
                  case 'today':
                    _setRange(StatDateRange.today());
                  case 'yesterday':
                    _setRange(StatDateRange.yesterday());
                  case '7d':
                    _setRange(StatDateRange.lastDays(7));
                  case '30d':
                    _setRange(StatDateRange.lastDays(30));
                  case 'custom':
                    _pickCustomRange();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'today', child: Text('今天')),
                PopupMenuItem(value: 'yesterday', child: Text('昨天')),
                PopupMenuItem(value: '7d', child: Text('近 7 天')),
                PopupMenuItem(value: '30d', child: Text('近 30 天')),
                PopupMenuItem(value: 'custom', child: Text('自定义范围…')),
              ],
            ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshAll(base, slow, errors, geo),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                switch (value) {
                  case 'setting':
                    _openSetting();
                  case 'clear':
                    _clearStats(base, slow, errors, geo);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'setting',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('统计设置'),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_sweep_outlined,
                        color: theme.colorScheme.error),
                    title: Text(
                      '清空统计',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in _tabs) Tab(text: tab)],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(query: base),
            _UriTab(query: base),
            _SlowUriTab(
              query: slow,
              threshold: _threshold,
              onThresholdChanged: (v) => setState(() => _threshold = v),
            ),
            _IpTab(query: base),
            _GeoTab(
              query: geo,
              groupBy: _geoGroupBy,
              country: _geoCountry,
              onDrillDown: (groupBy, country) => setState(() {
                _geoGroupBy = groupBy;
                _geoCountry = country;
              }),
            ),
            _SpiderTab(query: base),
            _ClientTab(query: base),
            _ErrorTab(
              query: errors,
              status: _status,
              onStatusChanged: (v) => setState(() => _status = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 概览

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.query});

  final StatQuery query;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  StatMetric _metric = StatMetric.pv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overviewAsync = ref.watch(statOverviewProvider(widget.query));
    final realtimeAsync = ref.watch(statRealtimeProvider);

    return overviewAsync.when(
      loading: () => const LoadingView(message: '正在加载统计概览…'),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(statOverviewProvider(widget.query)),
      ),
      data: (overview) {
        final current = overview.current;
        final previous = overview.previous;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statOverviewProvider(widget.query));
            ref.invalidate(statRealtimeProvider);
            // 失败时 provider 进入错误态由 ErrorView 展示，这里吞掉异常，
            // 避免 RefreshIndicator 抛出未处理的 Future 错误。
            try {
              await ref.read(statOverviewProvider(widget.query).future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              SectionCard(
                title: '全站实时',
                trailing: IconButton(
                  tooltip: '刷新',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => ref.invalidate(statRealtimeProvider),
                ),
                child: realtimeAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    '实时数据获取失败：${errorMessage(e)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                  data: (realtime) => StatMetricGrid(
                    tiles: [
                      StatMetricTile(
                        label: '出站速率',
                        value: formatRate(realtime.bandwidth),
                        icon: Icons.upload_outlined,
                      ),
                      StatMetricTile(
                        label: '入站速率',
                        value: formatRate(realtime.bandwidthIn),
                        icon: Icons.download_outlined,
                      ),
                      StatMetricTile(
                        label: '请求速率',
                        value: '${realtime.rps.toStringAsFixed(2)} req/s',
                        icon: Icons.speed_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              SectionCard(
                title: '核心指标（与上一周期对比）',
                child: StatMetricGrid(
                  tiles: [
                    StatMetricTile(
                      label: '浏览量 PV',
                      value: formatCount(current.pv),
                      delta: formatDelta(current.pv, previous.pv),
                      deltaPositive: isDeltaPositive(current.pv, previous.pv),
                    ),
                    StatMetricTile(
                      label: '访客数 UV',
                      value: formatCount(current.uv),
                      delta: formatDelta(current.uv, previous.uv),
                      deltaPositive: isDeltaPositive(current.uv, previous.uv),
                    ),
                    StatMetricTile(
                      label: '独立 IP',
                      value: formatCount(current.ip),
                      delta: formatDelta(current.ip, previous.ip),
                      deltaPositive: isDeltaPositive(current.ip, previous.ip),
                    ),
                    StatMetricTile(
                      label: '请求数',
                      value: formatCount(current.requests),
                      delta:
                          formatDelta(current.requests, previous.requests),
                      deltaPositive:
                          isDeltaPositive(current.requests, previous.requests),
                    ),
                    StatMetricTile(
                      label: '出站流量',
                      value: formatBytes(current.bandwidth),
                      delta:
                          formatDelta(current.bandwidth, previous.bandwidth),
                      deltaPositive: isDeltaPositive(
                          current.bandwidth, previous.bandwidth),
                    ),
                    StatMetricTile(
                      label: '入站流量',
                      value: formatBytes(current.bandwidthIn),
                      delta: formatDelta(
                          current.bandwidthIn, previous.bandwidthIn),
                      deltaPositive: isDeltaPositive(
                          current.bandwidthIn, previous.bandwidthIn),
                    ),
                    StatMetricTile(
                      label: '错误数',
                      value: formatCount(current.errors),
                      delta: formatDelta(current.errors, previous.errors),
                      deltaPositive:
                          !isDeltaPositive(current.errors, previous.errors),
                    ),
                    StatMetricTile(
                      label: '蜘蛛请求',
                      value: formatCount(current.spiders),
                      delta: formatDelta(current.spiders, previous.spiders),
                      deltaPositive:
                          isDeltaPositive(current.spiders, previous.spiders),
                    ),
                    StatMetricTile(
                      label: '平均响应',
                      value: formatMilliseconds(current.avgRequestTimeMs),
                    ),
                    StatMetricTile(
                      label: '错误率',
                      value: formatPercent(current.errorRate),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: '趋势',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final metric in StatMetric.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(metric.label),
                                selected: _metric == metric,
                                onSelected: (_) =>
                                    setState(() => _metric = metric),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatSeriesChart(
                      series: overview.series,
                      previousSeries: overview.previousSeries,
                      metric: _metric,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '实线为当前周期，虚线为上一周期',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: '状态码分布',
                child: StatusCodeBars(totals: current),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- URI

class _UriTab extends ConsumerWidget {
  const _UriTab({required this.query});

  final StatQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statUrisProvider(query));
    final maxRequests = state.valueOrNull?.items
            .fold<int>(0, (max, e) => e.requests > max ? e.requests : max) ??
        0;

    return PagedStatList<UriRank>(
      state: state,
      onRefresh: () => ref.read(statUrisProvider(query).notifier).refresh(),
      onLoadMore: () => ref.read(statUrisProvider(query).notifier).loadMore(),
      itemBuilder: (context, item, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StatRankBar(
          label: item.uri,
          value: '${formatCount(item.requests)} 次',
          ratio: maxRequests == 0 ? 0 : item.requests / maxRequests,
          subtitle: '流量 ${formatBytes(item.bandwidth)}'
              ' · 平均 ${formatMilliseconds(item.avgRequestTimeMs)}',
          trailing: item.errors > 0 ? '错误 ${formatCount(item.errors)}' : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 慢请求

class _SlowUriTab extends ConsumerWidget {
  const _SlowUriTab({
    required this.query,
    required this.threshold,
    required this.onThresholdChanged,
  });

  final StatQuery query;
  final int threshold;
  final ValueChanged<int> onThresholdChanged;

  static const _options = <({int value, String label})>[
    (value: 0, label: '不限'),
    (value: 100, label: '≥100ms'),
    (value: 500, label: '≥500ms'),
    (value: 1000, label: '≥1s'),
    (value: 3000, label: '≥3s'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statSlowUrisProvider(query));
    final maxTime = state.valueOrNull?.items.fold<double>(
          0,
          (max, e) => e.avgRequestTimeMs > max ? e.avgRequestTimeMs : max,
        ) ??
        0;

    return PagedStatList<UriRank>(
      state: state,
      header: _FilterHeader(
        title: '响应时间阈值',
        children: [
          for (final option in _options)
            ChoiceChip(
              label: Text(option.label),
              selected: threshold == option.value,
              onSelected: (_) => onThresholdChanged(option.value),
            ),
        ],
      ),
      onRefresh: () =>
          ref.read(statSlowUrisProvider(query).notifier).refresh(),
      onLoadMore: () =>
          ref.read(statSlowUrisProvider(query).notifier).loadMore(),
      itemBuilder: (context, item, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StatRankBar(
          label: item.uri,
          value: formatMilliseconds(item.avgRequestTimeMs),
          ratio: maxTime == 0 ? 0 : item.avgRequestTimeMs / maxTime,
          subtitle: '请求 ${formatCount(item.requests)} 次'
              ' · 流量 ${formatBytes(item.bandwidth)}',
          trailing: item.errors > 0 ? '错误 ${formatCount(item.errors)}' : null,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- IP

class _IpTab extends ConsumerWidget {
  const _IpTab({required this.query});

  final StatQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statIpsProvider(query));
    final maxRequests = state.valueOrNull?.items
            .fold<int>(0, (max, e) => e.requests > max ? e.requests : max) ??
        0;

    return PagedStatList<IpRank>(
      state: state,
      onRefresh: () => ref.read(statIpsProvider(query).notifier).refresh(),
      onLoadMore: () => ref.read(statIpsProvider(query).notifier).loadMore(),
      itemBuilder: (context, item, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StatRankBar(
          label: item.ip,
          value: '${formatCount(item.requests)} 次',
          ratio: maxRequests == 0 ? 0 : item.requests / maxRequests,
          subtitle: [
            if (item.location.isNotEmpty) item.location,
            if (item.isp.isNotEmpty) item.isp,
          ].join(' · '),
          trailing: formatBytes(item.bandwidth),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 地区

class _GeoTab extends ConsumerWidget {
  const _GeoTab({
    required this.query,
    required this.groupBy,
    required this.country,
    required this.onDrillDown,
  });

  final StatQuery query;
  final String groupBy;
  final String country;
  final void Function(String groupBy, String country) onDrillDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(statGeosProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(statGeosProvider(query));
        try {
          await ref.read(statGeosProvider(query).future);
        } catch (_) {}
      },
      child: async.when(
        loading: () => const LoadingView(message: '正在加载地区统计…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(statGeosProvider(query)),
        ),
        data: (items) {
          final maxRequests = items.fold<int>(
              0, (max, e) => e.requests > max ? e.requests : max);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _FilterHeader(
                title: '统计维度',
                children: [
                  ChoiceChip(
                    label: const Text('国家'),
                    selected: groupBy == 'country',
                    onSelected: (_) => onDrillDown('country', ''),
                  ),
                  ChoiceChip(
                    label: Text(
                      country.isEmpty ? '省份' : '省份（$country）',
                    ),
                    selected: groupBy == 'region',
                    onSelected: (_) => onDrillDown('region', country),
                  ),
                  ChoiceChip(
                    label: const Text('城市'),
                    selected: groupBy == 'city',
                    onSelected: (_) => onDrillDown('city', country),
                  ),
                ],
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      '所选时间范围内暂无数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StatRankBar(
                    label: item.label,
                    value: '${formatCount(item.requests)} 次',
                    ratio:
                        maxRequests == 0 ? 0 : item.requests / maxRequests,
                    trailing: formatBytes(item.bandwidth),
                    onTap: groupBy == 'country' && item.country.isNotEmpty
                        ? () => onDrillDown('region', item.country)
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ 蜘蛛

class _SpiderTab extends ConsumerWidget {
  const _SpiderTab({required this.query});

  final StatQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(statSpidersProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(statSpidersProvider(query));
        try {
          await ref.read(statSpidersProvider(query).future);
        } catch (_) {}
      },
      child: async.when(
        loading: () => const LoadingView(message: '正在加载蜘蛛统计…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(statSpidersProvider(query)),
        ),
        data: (stats) {
          if (stats.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    '所选时间范围内没有蜘蛛访问',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          }
          final maxRequests = stats.items.fold<int>(
              0, (max, e) => e.requests > max ? e.requests : max);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '蜘蛛请求合计 ${formatCount(stats.total)} 次',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in stats.items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StatRankBar(
                    label: item.spider,
                    value: '${formatCount(item.requests)} 次',
                    ratio:
                        maxRequests == 0 ? 0 : item.requests / maxRequests,
                    trailing: formatPercent(item.percent),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- 客户端

class _ClientTab extends ConsumerWidget {
  const _ClientTab({required this.query});

  final StatQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(statClientsProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(statClientsProvider(query));
        try {
          await ref.read(statClientsProvider(query).future);
        } catch (_) {}
      },
      child: async.when(
        loading: () => const LoadingView(message: '正在加载客户端统计…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(statClientsProvider(query)),
        ),
        data: (stats) {
          final maxBrowser = stats.browsers.fold<int>(
              0, (max, e) => e.requests > max ? e.requests : max);
          final maxOs = stats.os
              .fold<int>(0, (max, e) => e.requests > max ? e.requests : max);
          final maxItem = stats.items
              .fold<int>(0, (max, e) => e.requests > max ? e.requests : max);

          if (stats.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    '所选时间范围内暂无数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              SectionCard(
                title: '浏览器',
                child: Column(
                  children: [
                    for (final item in stats.browsers.take(10))
                      StatRankBar(
                        label: item.name.isEmpty ? '未知' : item.name,
                        value: '${formatCount(item.requests)} 次',
                        ratio: maxBrowser == 0
                            ? 0
                            : item.requests / maxBrowser,
                      ),
                  ],
                ),
              ),
              SectionCard(
                title: '操作系统',
                child: Column(
                  children: [
                    for (final item in stats.os.take(10))
                      StatRankBar(
                        label: item.name.isEmpty ? '未知' : item.name,
                        value: '${formatCount(item.requests)} 次',
                        ratio: maxOs == 0 ? 0 : item.requests / maxOs,
                      ),
                  ],
                ),
              ),
              SectionCard(
                title: '组合明细',
                child: Column(
                  children: [
                    for (final item in stats.items.take(50))
                      StatRankBar(
                        label:
                            '${item.browser.isEmpty ? '未知' : item.browser}'
                            ' / ${item.os.isEmpty ? '未知' : item.os}',
                        value: '${formatCount(item.requests)} 次',
                        ratio:
                            maxItem == 0 ? 0 : item.requests / maxItem,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '客户端明细最多展示 100 条（面板接口限制）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ 错误

class _ErrorTab extends ConsumerWidget {
  const _ErrorTab({
    required this.query,
    required this.status,
    required this.onStatusChanged,
  });

  final StatQuery query;
  final int status;
  final ValueChanged<int> onStatusChanged;

  static const _statuses = [0, 400, 401, 403, 404, 429, 500, 502, 503, 504];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(statErrorsProvider(query));

    return PagedStatList<ErrorLogItem>(
      state: state,
      header: _FilterHeader(
        title: '状态码',
        children: [
          for (final code in _statuses)
            ChoiceChip(
              label: Text(code == 0 ? '全部' : '$code'),
              selected: status == code,
              onSelected: (_) => onStatusChanged(code),
            ),
        ],
      ),
      onRefresh: () => ref.read(statErrorsProvider(query).notifier).refresh(),
      onLoadMore: () =>
          ref.read(statErrorsProvider(query).notifier).loadMore(),
      emptyMessage: '所选条件下没有错误请求',
      itemBuilder: (context, item, index) => ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: item.status >= 500
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.secondaryContainer,
          child: Text(
            '${item.status}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: item.status >= 500
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        title: Text(
          '${item.method} ${item.uri}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          '${formatDateTime(item.createdAt)} · ${item.ip}\n${item.ua}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${item.status} ${item.method}'),
            content: SingleChildScrollView(
              child: SelectableText(
                [
                  'URI：${item.uri}',
                  '时间：${formatDateTime(item.createdAt)}',
                  'IP：${item.ip}',
                  'User-Agent：${item.ua}',
                  if (item.body.isNotEmpty) '请求体：\n${item.body}',
                ].join('\n\n'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 列表顶部筛选条。
class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: children),
        ],
      ),
    );
  }
}
