import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 页面依赖的面板应用未安装时的专门空态。
///
/// 用于替代把面板原始报错直接丢给用户的通用 [ErrorView]：
/// 说明缺什么、并提供「去应用商店安装」入口（跳转 `/apps`）。
/// 从应用商店返回后回调 [onRecheck]，供页面重新检测 / 刷新列表。
class NotInstalledView extends StatelessWidget {
  const NotInstalledView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.extension_off_outlined,
    this.onRecheck,
  });

  /// 标题，如「未安装容器引擎」。
  final String title;

  /// 说明文案，告知用户需要安装什么。
  final String message;

  final IconData icon;

  /// 从应用商店返回或点击「重新检测」时的回调。
  final VoidCallback? onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await GoRouter.of(context).push('/apps');
                onRecheck?.call();
              },
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('去应用商店安装'),
            ),
            if (onRecheck != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRecheck,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新检测'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
