import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/servers_providers.dart';
import 'connection_test_result_card.dart';

/// 对已保存的服务器执行连接测试，并以对话框展示结果。
///
/// [serverId] 为服务器配置的 id；失败时可原地重试。
Future<void> showConnectionTestDialog(
  BuildContext context, {
  required String serverId,
  required String serverName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ConnectionTestDialog(
      serverId: serverId,
      serverName: serverName,
    ),
  );
}

class _ConnectionTestDialog extends ConsumerWidget {
  const _ConnectionTestDialog({
    required this.serverId,
    required this.serverName,
  });

  final String serverId;
  final String serverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final testAsync = ref.watch(serverConnectionTestProvider(serverId));

    return AlertDialog(
      title: Text('测试「$serverName」'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: testAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '正在测试连接…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, _) => ConnectionTestErrorCard(error: error),
            data: (result) => ConnectionTestResultCard(result: result),
          ),
        ),
      ),
      actions: [
        if (!testAsync.isLoading)
          TextButton(
            onPressed: () =>
                ref.invalidate(serverConnectionTestProvider(serverId)),
            child: const Text('重新测试'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
