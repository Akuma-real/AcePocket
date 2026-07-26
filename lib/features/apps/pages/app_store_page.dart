import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/task_snack.dart';
import '../models/app_category.dart';
import '../models/app_item.dart';
import '../providers/apps_providers.dart';
import '../widgets/app_channel_sheet.dart';
import '../widgets/app_custom_dialog.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/app_order_sheet.dart';
import '../widgets/paged_list_footer.dart';

/// 应用商店页面（/apps）。
///
/// 「已安装」与「全部」两个标签页共用分类与关键词筛选，
/// 支持安装 / 卸载 / 更新、首页显示开关、首页排序与应用缓存更新。
class AppStorePage extends ConsumerStatefulWidget {
  const AppStorePage({super.key});

  @override
  ConsumerState<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends ConsumerState<AppStorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _updatingCache = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.text = ref.read(appFilterProvider).keyword;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(appFilterProvider.notifier).setKeyword(value.trim());
    });
  }

  Future<void> _updateCache() async {
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    setState(() => _updatingCache = true);
    try {
      await repo.updateCache();
      if (!mounted) return;
      ref.invalidate(appCategoriesProvider);
      refreshAllAppLists(ref);
      _toast('应用缓存已更新');
    } catch (e) {
      if (!mounted) return;
      _toast('更新缓存失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _updatingCache = false);
    }
  }

  Future<void> _openOrderSheet() async {
    final saved = await showAppOrderSheet(context);
    if (!mounted || !saved) return;
    refreshAllAppLists(ref);
    _toast('排序已保存');
  }

  void _toast(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(appFilterProvider);
    final categories = ref.watch(appCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('应用商店'),
        actions: [
          IconButton(
            tooltip: '更新应用缓存',
            onPressed: _updatingCache ? null : _updateCache,
            icon: _updatingCache
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'order') _openOrderSheet();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'order',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_vert),
                  title: Text('首页显示排序'),
                ),
              ),
            ],
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
                  .read(appFilterProvider.notifier)
                  .setKeyword(value.trim()),
              decoration: InputDecoration(
                hintText: '搜索应用名称或描述',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          ref.read(appFilterProvider.notifier).setKeyword('');
                        },
                      ),
              ),
            ),
          ),
          _CategoryBar(
            categories: categories,
            selected: filter.category,
            onSelected: (value) =>
                ref.read(appFilterProvider.notifier).setCategory(value),
          ),
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: '已安装'),
              Tab(text: '全部应用'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _AppListView(installedOnly: true),
                _AppListView(installedOnly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类筛选条。
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final AsyncValue<List<AppCategory>> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final list = categories.valueOrNull ?? const <AppCategory>[];
    if (list.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: list.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = index == 0 ? '' : list[index - 1].value;
          final label = index == 0 ? '全部' : list[index - 1].label;
          return ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          );
        },
      ),
    );
  }
}

/// 单个标签页的应用列表。
class _AppListView extends ConsumerStatefulWidget {
  const _AppListView({required this.installedOnly});

  final bool installedOnly;

  @override
  ConsumerState<_AppListView> createState() => _AppListViewState();
}

class _AppListViewState extends ConsumerState<_AppListView>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busySlugs = <String>{};
  bool _loadingMore = false;

  @override
  bool get wantKeepAlive => true;

  AppListNotifier get _notifier =>
      ref.read(appListProvider(widget.installedOnly).notifier);

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

  Future<void> _run(
    String slug,
    Future<void> Function() action, {
    required String successMessage,
    bool refreshLists = true,
    bool task = false,
  }) async {
    if (_busySlugs.contains(slug)) return;
    setState(() => _busySlugs.add(slug));
    try {
      await action();
      if (!mounted) return;
      if (task) {
        showTaskSubmittedSnack(context, successMessage);
      } else {
        _toast(successMessage);
      }
      if (refreshLists) refreshAllAppLists(ref);
    } catch (e) {
      _toast('操作失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busySlugs.remove(slug));
    }
  }

  Future<void> _install(AppItem app) async {
    final channel = await showAppChannelSheet(context, app: app);
    if (channel == null || !mounted) return;
    final version = channel.version.isEmpty ? channel.name : channel.version;
    final ok = await showConfirmDialog(
      context,
      title: '安装 ${app.name}',
      content: '确定安装 ${app.name}（$version）吗？\n'
          '安装任务将在面板后台执行，可在面板的后台任务中查看进度。',
      confirmText: '安装',
    );
    if (!ok || !mounted) return;
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    await _run(
      app.slug,
      () => repo.install(slug: app.slug, channel: channel.slug),
      successMessage: '安装任务已提交',
      task: true,
    );
  }

  Future<void> _update(AppItem app) async {
    final target = app.targetVersion;
    final ok = await showConfirmDialog(
      context,
      title: '更新 ${app.name}',
      content: '确定将 ${app.name} 更新到 ${target.isEmpty ? '最新版本' : target} 吗？\n'
          '更新可能会将相关配置重置为默认状态。',
      confirmText: '更新',
      danger: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    await _run(
      app.slug,
      () => repo.update(app.slug),
      successMessage: '更新任务已提交',
      task: true,
    );
  }

  Future<void> _uninstall(AppItem app) async {
    final isWebServer = app.categories.contains('webserver');
    final ok = await showConfirmDialog(
      context,
      title: '卸载 ${app.name}',
      content: isWebServer
          ? '${app.name} 是 Web 服务器，重装或切换到其他 Web 服务器会重置所有网站的配置，确定卸载吗？'
          : '确定卸载 ${app.name} 吗？该操作不可恢复，应用数据可能一并删除。',
      confirmText: '卸载',
      danger: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    await _run(
      app.slug,
      () => repo.uninstall(app.slug),
      successMessage: '卸载任务已提交',
      task: true,
    );
  }

  Future<void> _toggleShow(AppItem app, bool show) async {
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    await _run(
      app.slug,
      () async {
        await repo.updateShow(slug: app.slug, show: show);
        _notifier.patch(app.slug, (item) => item.copyWith(show: show));
        ref
            .read(appListProvider(!widget.installedOnly).notifier)
            .patch(app.slug, (item) => item.copyWith(show: show));
      },
      successMessage: show ? '已开启首页显示' : '已关闭首页显示',
      refreshLists: false,
    );
  }

  Future<void> _custom(AppItem app) async {
    final saved = await showAppCustomDialog(context, app: app);
    if (saved) _toast('编译参数已保存');
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    final error = await _notifier.loadMore();
    _loadingMore = false;
    if (error != null) _toast('加载更多失败：$error', error: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(appListProvider(widget.installedOnly));
    final categories = ref.watch(appCategoriesProvider).valueOrNull ??
        const <AppCategory>[];
    final categoryLabels = {
      for (final c in categories) c.value: c.label,
    };

    if (state.isLoading && state.items.isEmpty) {
      return const LoadingView(message: '加载应用列表…');
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
                    child: EmptyView(
                      message: widget.installedOnly
                          ? '还没有已安装的应用\n可在「全部应用」中安装'
                          : '没有匹配的应用\n可尝试更换分类或关键词',
                      icon: Icons.apps_outlined,
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
                      emptyLabel: '共 %d 个应用',
                    );
                  }
                  final app = state.items[index];
                  return AppListTile(
                    app: app,
                    categoryLabels: categoryLabels,
                    busy: _busySlugs.contains(app.slug),
                    onInstall: () => _install(app),
                    onUpdate: () => _update(app),
                    onUninstall: () => _uninstall(app),
                    onToggleShow: (value) => _toggleShow(app, value),
                    onCustom: () => _custom(app),
                  );
                },
              ),
      ),
    );
  }
}
