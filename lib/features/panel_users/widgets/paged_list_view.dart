import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
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
    this.totalLabel = _defaultTotalLabel,
  });

  static String _defaultTotalLabel(int total) => '共 $total 条';

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

  /// 全部加载完毕时列表底部的合计文案（默认「共 n 条」，调用方可换成业务量词）。
  final String Function(int total) totalLabel;

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
    // 上一页加载失败后不再自动重试：否则用户每滑一下就重发一次注定失败的请求，
    // 面板不可达时会变成持续的请求风暴。改为由底部「重试」按钮显式触发。
    if (widget.state.valueOrNull?.loadMoreError != null) return;
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
            error: paged.loadMoreError,
            totalLabel: widget.totalLabel,
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
    required this.error,
    required this.totalLabel,
    required this.onLoadMore,
  });

  final bool loading;
  final bool hasMore;
  final int total;

  /// 加载下一页失败时的错误；展示原因并提供重试。
  final Object? error;
  final String Function(int total) totalLabel;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 加载下一页失败：说明原因并提供重试，否则用户只会看到列表停在半路。
    final loadMoreError = error;
    if (!loading && loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Text(
              '加载更多失败：${describeError(loadMoreError)}',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

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
        totalLabel(total),
        textAlign: TextAlign.center,
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
