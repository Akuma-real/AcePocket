import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

/// 未保存修改的返回拦截。
///
/// 包裹页面主体（通常是整个 `Scaffold`），[hasUnsavedChanges] 为 true 时拦截
/// **系统返回手势与实体返回键**，弹出确认对话框（「放弃修改」/「继续编辑」），
/// 用户确认后才真正退出。
///
/// 解决的问题：多个编辑页只在 AppBar 返回箭头的回调里做了确认，而 Android 的
/// 侧滑返回 / 返回键会绕过它静默丢弃草稿，同一页面两条返回路径行为不一致。
///
/// 用法：
/// ```dart
/// UnsavedChangesGuard(
///   hasUnsavedChanges: _dirty,
///   child: Scaffold(...),
/// )
/// ```
/// AppBar 的自定义返回按钮直接调用 `Navigator.maybePop(context)` 即可复用
/// 本组件的确认流程（`maybePop` 会走 [PopScope]，`pop` 不会）。
///
/// 与 `lib/core/router/router.dart` 中 `_MainShell` 的 [PopScope] 互不干扰：
/// 那一个注册在底部导航 shell 路由上，用于 tab 历史回退；本组件用于 shell 之上
/// 顶层 push 的整页路由。返回事件只投递给**栈顶路由**的 PopScope，顶层页面在栈上
/// 时 shell 的 PopScope 收不到事件；本页真正 pop 之后才轮到 shell 处理。
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.message = '有未保存的修改，确定放弃吗？',
    this.onDiscard,
  });

  /// 是否存在未保存的草稿。false 时本组件完全透明，不拦截任何返回。
  final bool hasUnsavedChanges;

  /// 页面主体。
  final Widget child;

  /// 确认对话框正文。
  final String message;

  /// 用户选择「放弃修改」后、真正退出前的回调（如清理临时文件、重置 Notifier）。
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) =>
          _handlePop(context, didPop, result),
      child: child,
    );
  }

  Future<void> _handlePop(
    BuildContext context,
    bool didPop,
    Object? result,
  ) async {
    // didPop 为 true 表示路由已经出栈（canPop 为 true 的正常情况），无需处理。
    if (didPop) return;

    // 对话框是异步的，await 之后原 context 可能已失效，先取 Navigator。
    final navigator = Navigator.of(context);
    final discard = await showConfirmDialog(
      context,
      title: '放弃修改',
      content: message,
      confirmText: '放弃修改',
      cancelText: '继续编辑',
      danger: true,
    );
    if (!discard) return;
    onDiscard?.call();
    // 此时 canPop 仍为 false（调用方的 dirty 状态未变），必须用 pop 而非
    // maybePop —— maybePop 会再次触发本拦截，陷入死循环。
    if (navigator.mounted) navigator.pop(result);
  }
}
