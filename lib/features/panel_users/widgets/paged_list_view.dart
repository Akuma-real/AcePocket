import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/panel_user_providers.dart';

/// 分页列表通用视图：下拉刷新 + 触底自动加载下一页 + 空态 / 错误态处理。
///
/// 数据来自继承 [PagedNotifier] 的 provider，[state] 直接传 `ref.watch(...)`。
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.itemBuilder,
    this.header,
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

  /// 列表顶部固定内容（如说明卡片），空列表时同样展示。
  final Widget? header;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.header != null) widget.header!,
                  EmptyView(
                    message: widget.emptyMessage,
                    icon: widget.emptyIcon,
                    action: widget.emptyAction,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final headerCount = widget.header == null ? 0 : 1;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: items.length + headerCount + 1,
        itemBuilder: (context, index) {
          if (headerCount == 1 && index == 0) return widget.header!;
          final itemIndex = index - headerCount;
          if (itemIndex < items.length) {
            return widget.itemBuilder(context, items[itemIndex], itemIndex);
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
        '共 $total 个用户',
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
