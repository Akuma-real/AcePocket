import 'package:flutter/material.dart';

/// 分页列表底部提示：加载中 / 上拉加载更多 / 合计条数。
class ListFooter extends StatelessWidget {
  const ListFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.total,
    required this.unit,
  });

  final bool loading;
  final bool hasMore;
  final int total;

  /// 合计文案的量词，如「个项目」「个模板」。
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
