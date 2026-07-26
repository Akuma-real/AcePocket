import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

/// 终端快捷键条：手机软键盘缺失的按键（Esc / Tab / 方向键 / Ctrl 组合 / 常用符号）。
///
/// - 功能键通过 [onKey] 交给 xterm 生成序列（会区分光标应用模式）；
/// - Ctrl 组合与符号通过 [onText] 直接写入 PTY 输入。
class TerminalKeyboardBar extends StatelessWidget {
  const TerminalKeyboardBar({
    super.key,
    required this.onKey,
    required this.onText,
    required this.onCtrl,
    required this.enabled,
  });

  /// 功能键（Esc / Tab / 方向键 / Home / End / PgUp / PgDn / Del）。
  final void Function(TerminalKey key) onKey;

  /// 原始文本（符号等）。
  final void Function(String text) onText;

  /// Ctrl + 字母（传入单个字母，如 `C`）。
  final void Function(String letter) onCtrl;

  /// 未连接时禁用。
  final bool enabled;

  static const List<(String, String)> _ctrlCombos = [
    ('C', '中断当前命令'),
    ('D', '结束输入 / 退出'),
    ('Z', '挂起到后台'),
    ('L', '清屏'),
    ('A', '移到行首'),
    ('E', '移到行尾'),
    ('U', '删除到行首'),
    ('K', '删除到行尾'),
    ('W', '删除前一个单词'),
    ('R', '搜索历史命令'),
  ];

  static const List<String> _symbols = [
    '/', '-', '_', '|', '~', '.', '*', '\$', '&', '>', '<', ':', '"', "'",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              _CtrlMenuButton(enabled: enabled, onCtrl: onCtrl),
              _KeyChip(
                label: 'Esc',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.escape),
              ),
              _KeyChip(
                label: 'Tab',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.tab),
              ),
              _KeyChip(
                label: '^C',
                tooltip: 'Ctrl+C 中断',
                emphasized: true,
                enabled: enabled,
                onTap: () => onCtrl('C'),
              ),
              _KeyChip(
                icon: Icons.keyboard_arrow_up,
                enabled: enabled,
                onTap: () => onKey(TerminalKey.arrowUp),
              ),
              _KeyChip(
                icon: Icons.keyboard_arrow_down,
                enabled: enabled,
                onTap: () => onKey(TerminalKey.arrowDown),
              ),
              _KeyChip(
                icon: Icons.keyboard_arrow_left,
                enabled: enabled,
                onTap: () => onKey(TerminalKey.arrowLeft),
              ),
              _KeyChip(
                icon: Icons.keyboard_arrow_right,
                enabled: enabled,
                onTap: () => onKey(TerminalKey.arrowRight),
              ),
              _KeyChip(
                label: 'Home',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.home),
              ),
              _KeyChip(
                label: 'End',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.end),
              ),
              _KeyChip(
                label: 'PgUp',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.pageUp),
              ),
              _KeyChip(
                label: 'PgDn',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.pageDown),
              ),
              _KeyChip(
                label: 'Del',
                enabled: enabled,
                onTap: () => onKey(TerminalKey.delete),
              ),
              for (final symbol in _symbols)
                _KeyChip(
                  label: symbol,
                  enabled: enabled,
                  onTap: () => onText(symbol),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ctrl 组合键下拉。
class _CtrlMenuButton extends StatelessWidget {
  const _CtrlMenuButton({required this.enabled, required this.onCtrl});

  final bool enabled;
  final void Function(String letter) onCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: 'Ctrl 组合键',
        position: PopupMenuPosition.over,
        onSelected: (letter) {
          HapticFeedback.selectionClick();
          onCtrl(letter);
        },
        itemBuilder: (context) => [
          for (final combo in TerminalKeyboardBar._ctrlCombos)
            PopupMenuItem<String>(
              value: combo.$1,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      'Ctrl+${combo.$1}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    combo.$2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ctrl',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: enabled
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个按键。
class _KeyChip extends StatelessWidget {
  const _KeyChip({
    this.label,
    this.icon,
    this.tooltip,
    this.emphasized = false,
    required this.enabled,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool emphasized;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = !enabled
        ? scheme.surfaceContainerHighest
        : emphasized
            ? scheme.errorContainer
            : scheme.surfaceContainer;
    final foreground = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : emphasized
            ? scheme.onErrorContainer
            : scheme.onSurface;

    final content = Container(
      constraints: const BoxConstraints(minWidth: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: icon != null
          ? Icon(icon, size: 20, color: foreground)
          : Text(
              label ?? '',
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip ?? label ?? '',
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: content,
        ),
      ),
    );
  }
}
