import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 分页列表底部：加载更多进度 / 失败重试 / 「共 N 项」提示。
///
/// 触发加载更多由列表的滚动通知负责（见各页面的 `NotificationListener`），
/// 本组件只负责展示。
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.hasMore,
    required this.total,
    this.emptyLabel = '共 %d 项',
    this.error,
    this.onRetry,
  });

  /// 是否还有下一页。
  final bool hasMore;

  /// 服务端返回的总条数。
  final int total;

  /// 已加载完毕时的文案模板，`%d` 会替换为总条数。
  final String emptyLabel;

  /// 上一次「加载更多」的失败原因；为空表示正常。
  final Object? error;

  /// 失败后的重试回调。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 加载更多失败后如果继续转圈，用户会一直等一个永远不会到来的结果，
    // 这里明确给出失败原因与重试入口。
    if (hasMore && error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(
              '加载更多失败：${describeError(error!)}',
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
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: hasMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                emptyLabel.replaceAll('%d', '$total'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
