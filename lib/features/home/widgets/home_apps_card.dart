import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';
import 'info_row.dart';

/// 首页展示应用（`GET /home/apps`）：面板中标记为「首页显示」的已安装应用。
class HomeAppsCard extends ConsumerWidget {
  const HomeAppsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(homeAppsProvider);

    // 未配置首页应用时不占位。
    if (async.valueOrNull != null && async.valueOrNull!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: '已安装应用',
      child: async.when(
        loading: () => const SizedBox(
          height: 48,
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
          onRetry: () => ref.invalidate(homeAppsProvider),
        ),
        data: (apps) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final app in apps)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.name.isEmpty ? app.slug : app.name,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (app.version.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        app.version,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
