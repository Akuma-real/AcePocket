import 'package:flutter/material.dart';

/// 分页列表底部：加载更多指示 / 合计条数。
class ListFooter extends StatelessWidget {
  const ListFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.total,
  });

  /// 是否正在加载下一页。
  final bool loading;

  /// 是否还有更多数据。
  final bool hasMore;

  /// 总条数。
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                hasMore ? '上拉加载更多' : '共 $total 条',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
