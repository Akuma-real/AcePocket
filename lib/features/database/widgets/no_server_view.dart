import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_view.dart';

/// 未配置 / 未选择面板服务器时的占位视图。
class NoServerView extends StatelessWidget {
  const NoServerView({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      message: '尚未选择面板服务器\n请先添加并选中一台 AcePanel 服务器',
      icon: Icons.dns_outlined,
      action: FilledButton.icon(
        onPressed: () => context.push('/servers/setup'),
        icon: const Icon(Icons.add),
        label: const Text('去配置服务器'),
      ),
    );
  }
}
