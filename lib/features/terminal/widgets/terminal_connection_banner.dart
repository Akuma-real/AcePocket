import 'package:flutter/material.dart';

/// 终端顶部提示条（断线提示 / 心跳异常提示）。
class TerminalConnectionBanner extends StatelessWidget {
  const TerminalConnectionBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  /// 断线提示（可重连）。
  factory TerminalConnectionBanner.disconnected(
    BuildContext context, {
    required String message,
    required VoidCallback onReconnect,
    bool busy = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TerminalConnectionBanner(
      message: message,
      icon: Icons.link_off,
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
      actionLabel: '重新连接',
      onAction: onReconnect,
      busy: busy,
    );
  }

  /// 心跳超时提示。
  factory TerminalConnectionBanner.unstable(
    BuildContext context, {
    required VoidCallback onReconnect,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TerminalConnectionBanner(
      message: '心跳无应答，连接可能已中断',
      icon: Icons.wifi_tethering_error,
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
      actionLabel: '重新连接',
      onAction: onReconnect,
    );
  }

  /// 重连中提示。
  factory TerminalConnectionBanner.connecting(
    BuildContext context, {
    String message = '正在重新连接…',
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TerminalConnectionBanner(
      message: message,
      icon: Icons.sync,
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      busy: true,
    );
  }

  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
