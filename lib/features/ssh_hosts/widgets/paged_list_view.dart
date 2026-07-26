import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/ssh_hosts_providers.dart';

/// 分页列表通用视图：下拉刷新 + 触底自动加载下一页 + 空态 / 错误态处理。
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
    this.padding = const EdgeInsets.fromLTRB(0, 4, 0, 96),
  });

  final AsyncValue<PagedState<T>> state;

  /// 下拉刷新回调（异常应在调用方捕获并提示）。
  final Future<void> Function() onRefresh;

  /// 触底加载下一页。
  final VoidCallback onLoadMore;

  /// 首次加载失败时的重试。
  final VoidCallback onRetry;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final EdgeInsetsGeometry padding;

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
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (!state.hasValue) {
      if (state.hasError) {
        return ErrorView(error: state.error!, onRetry: widget.onRetry);
      }
      return const LoadingView();
    }

    final paged = state.requireValue;
    final items = paged.items;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: EmptyView(
                message: widget.emptyMessage,
                icon: widget.emptyIcon,
                action: widget.emptyAction,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index < items.length) {
            return widget.itemBuilder(context, items[index], index);
          }
          return _Footer(
            loading: paged.loadingMore,
            hasMore: paged.hasMore,
            total: paged.total,
            onLoadMore: widget.onLoadMore,
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.hasMore,
    required this.total,
    required this.onLoadMore,
  });

  final bool loading;
  final bool hasMore;
  final int total;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (loading) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (hasMore) {
      child = TextButton(
        onPressed: onLoadMore,
        child: const Text('加载更多'),
      );
    } else {
      child = Text(
        '共 $total 台主机',
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
