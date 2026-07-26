import 'package:flutter/material.dart';

/// 分页列表底部：加载更多进度 / 「共 N 项」提示。
///
/// 触发加载更多由列表的滚动通知负责（见各页面的 `NotificationListener`），
/// 本组件只负责展示。
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.hasMore,
    required this.total,
    this.emptyLabel = '共 %d 项',
  });

  /// 是否还有下一页。
  final bool hasMore;

  /// 服务端返回的总条数。
  final int total;

  /// 已加载完毕时的文案模板，`%d` 会替换为总条数。
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
