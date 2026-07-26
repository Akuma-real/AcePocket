import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';
import 'formatters.dart';
import 'info_row.dart';

/// 资源统计卡片：网站 / 数据库 / 项目 / 计划任务 / 容器数量。
class CountInfoCard extends ConsumerWidget {
  const CountInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(countInfoProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '资源统计',
      child: async.when(
        loading: () => const SizedBox(
          height: 64,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => InlineError(
          message: error is ApiException ? error.message : '$error',
          onRetry: () => ref.invalidate(countInfoProvider),
        ),
        data: (info) => Row(
          children: [
            Expanded(
              child: MetricTile(
                label: '网站',
                value: formatCount(info.website),
                icon: Icons.language_rounded,
              ),
            ),
            Expanded(
              child: MetricTile(
                label: '数据库',
                value: formatCount(info.database),
                icon: Icons.storage_rounded,
                color: theme.colorScheme.secondary,
              ),
            ),
            Expanded(
              child: MetricTile(
                label: '项目',
                value: formatCount(info.project),
                icon: Icons.rocket_launch_outlined,
                color: theme.colorScheme.tertiary,
              ),
            ),
            Expanded(
              child: MetricTile(
                label: '计划任务',
                value: formatCount(info.cron),
                icon: Icons.schedule_rounded,
              ),
            ),
            Expanded(
              child: MetricTile(
                label: '容器',
                value: formatCount(info.container),
                icon: Icons.widgets_outlined,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
