import 'package:flutter/material.dart';

import '../providers/paged_state.dart';
import 'feedback.dart';

/// 通用分页列表：下拉刷新 + 滚动到底自动加载下一页 + 底部状态提示。
///
/// 「加载下一页」的失败不再抛给调用方，而是由基类记入
/// [PagedState.loadMoreError]，在列表底部展示「加载失败，点击重试」——
/// 避免失败后自动加载被反复触发、SnackBar 连环弹出。
class PagedList<T> extends StatelessWidget {
  const PagedList({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.emptyView,
    this.header,
    this.padding = const EdgeInsets.only(top: 8, bottom: 96),
  });

  final PagedState<T> state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 列表为空时展示的内容。
  final Widget emptyView;

  /// 固定置顶的头部（如说明条、筛选栏），空列表时同样展示。
  final Widget? header;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    if (header != null) header!,
                    SizedBox(
                      height: constraints.maxHeight * 0.6,
                      child: emptyView,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final headerCount = header != null ? 1 : 0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            final metrics = notification.metrics;
            if (metrics.axis == Axis.vertical &&
                metrics.pixels >= metrics.maxScrollExtent - 240 &&
                state.hasMore &&
                !state.loadingMore &&
                // 上一页失败后不自动重试，等用户点击底部的「重试」。
                state.loadMoreError == null) {
              onLoadMore();
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: padding,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: headerCount + state.items.length + 1,
          itemBuilder: (context, index) {
            if (headerCount == 1 && index == 0) return header!;
            final dataIndex = index - headerCount;
            if (dataIndex < state.items.length) {
              return itemBuilder(context, state.items[dataIndex], dataIndex);
            }
            return _Footer(
              loading: state.loadingMore,
              hasMore: state.hasMore,
              total: state.total,
              error: state.loadMoreError,
              onLoadMore: onLoadMore,
            );
          },
        ),
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
    required this.onLoadMore,
  });

  final bool loading;
  final bool hasMore;
  final int total;

  /// 加载下一页失败时的错误；非空时展示错误文案与「重试」。
  final Object? error;

  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (loading) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (error != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              describeError(error!),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => onLoadMore(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试加载下一页'),
          ),
        ],
      );
    } else if (hasMore) {
      child = TextButton(
        onPressed: () => onLoadMore(),
        child: const Text('加载更多'),
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
