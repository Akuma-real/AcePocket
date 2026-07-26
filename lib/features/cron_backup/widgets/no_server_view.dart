import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';

/// 未选择服务器时的占位视图。
class NoServerView extends StatelessWidget {
  const NoServerView({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyView(
      icon: Icons.dns_outlined,
      message: '尚未选择服务器\n请先在「服务器」中添加并选择一台面板服务器',
    );
  }
}
