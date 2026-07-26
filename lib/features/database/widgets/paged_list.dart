import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/paged_state.dart';
import 'db_feedback.dart';

/// 分页列表视图：下拉刷新 + 滚动到底自动加载下一页 + 错误重试 + 空状态。
class PagedListView<T> extends StatelessWidget {
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
    this.padding = const EdgeInsets.only(top: 8, bottom: 96),
  });

  /// 列表状态。
  final AsyncValue<PagedState<T>> state;

  /// 下拉刷新。
  final Future<void> Function() onRefresh;

  /// 加载下一页。
  final VoidCallback onLoadMore;

  /// 整页错误后的重试。
  final VoidCallback onRetry;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
      data: (paged) => RefreshIndicator(
        onRefresh: onRefresh,
        child: paged.isEmpty ? _buildEmpty(context) : _buildList(context, paged),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyView(
            message: emptyMessage,
            icon: emptyIcon,
            action: emptyAction,
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, PagedState<T> paged) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical &&
            paged.hasMore &&
            !paged.isLoadingMore &&
            paged.loadMoreError == null &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: paged.items.length + 1,
        itemBuilder: (context, index) {
          if (index == paged.items.length) {
            return _Footer(paged: paged, onLoadMore: onLoadMore);
          }
          return itemBuilder(context, paged.items[index], index);
        },
      ),
    );
  }
}

class _Footer<T> extends StatelessWidget {
  const _Footer({required this.paged, required this.onLoadMore});

  final PagedState<T> paged;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (paged.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (paged.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Text(
              describeError(paged.loadMoreError!),
              textAlign: TextAlign.center,
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

    if (paged.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton(onPressed: onLoadMore, child: const Text('加载更多')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '共 ${paged.total} 条',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}
