import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/container_providers.dart';

/// 容器模块统一的分页列表：下拉刷新 + 触底加载更多 + 错误重试 + 空态。
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.itemBuilder,
    this.emptyMessage = '暂无数据',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.loadingMessage,
    this.header,
    this.bottomPadding = 88,
  });

  final AsyncValue<PagedState<T>> state;

  /// 下拉刷新（异常应在内部处理或抛出，由本组件捕获展示）。
  final Future<void> Function() onRefresh;

  /// 触底加载更多。
  final Future<void> Function() onLoadMore;

  /// 首屏加载失败后的重试。
  final VoidCallback onRetry;

  final Widget Function(BuildContext context, T item) itemBuilder;

  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final String? loadingMessage;

  /// 列表顶部固定内容（随列表滚动）。
  final Widget? header;

  /// 底部留白（为悬浮按钮让位）。
  final double bottomPadding;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      // 重复触发由 Notifier 内部的 loadingMore / hasMore 拦截。
      widget.onLoadMore();
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.onRefresh();
    } catch (error) {
      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '刷新失败：$error',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.state.when(
      loading: () => LoadingView(message: widget.loadingMessage),
      error: (error, _) => ErrorView(error: error, onRetry: widget.onRetry),
      data: (paged) {
        if (paged.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (widget.header != null) widget.header!,
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                EmptyView(
                  message: widget.emptyMessage,
                  icon: widget.emptyIcon,
                  action: widget.emptyAction,
                ),
              ],
            ),
          );
        }

        final headerCount = widget.header == null ? 0 : 1;
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView.builder(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 4, bottom: widget.bottomPadding),
            itemCount: paged.items.length + headerCount + 1,
            itemBuilder: (context, index) {
              if (headerCount == 1 && index == 0) return widget.header!;
              final itemIndex = index - headerCount;
              if (itemIndex == paged.items.length) {
                return _Footer(
                  loadingMore: paged.loadingMore,
                  hasMore: paged.hasMore,
                  loaded: paged.items.length,
                  total: paged.total,
                );
              }
              return widget.itemBuilder(context, paged.items[itemIndex]);
            },
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loadingMore,
    required this.hasMore,
    required this.loaded,
    required this.total,
  });

  final bool loadingMore;
  final bool hasMore;
  final int loaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (loadingMore) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (hasMore) {
      child = Text(
        '上拉加载更多（$loaded / $total）',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = Text(
        '共 $total 条',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: child),
    );
  }
}
