import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 分页列表底部提示：加载中 / 加载失败可重试 / 上拉加载更多 / 合计条数。
class ListFooter extends StatelessWidget {
  const ListFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.total,
    required this.unit,
    this.error,
    this.onRetry,
  });

  final bool loading;
  final bool hasMore;
  final int total;

  /// 合计文案的量词，如「个项目」「个模板」。
  final String unit;

  /// 加载下一页失败时的错误（展示后可点击重试）。
  final Object? error;

  /// 重试加载下一页。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadMoreError = error;
    if (!loading && loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Text(
              '加载失败：${describeError(loadMoreError)}',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                hasMore ? '上拉加载更多' : '共 $total $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
