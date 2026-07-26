import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/terminal_settings.dart';
import '../providers/terminal_providers.dart';

/// 弹出终端设置面板（字号 / 快捷键条 / 回滚行数 / 自动重连）。
Future<void> showTerminalSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const TerminalSettingsSheet(),
  );
}

/// 终端设置面板内容。
class TerminalSettingsSheet extends ConsumerWidget {
  const TerminalSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(terminalSettingsProvider);
    final notifier = ref.read(terminalSettingsProvider.notifier);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('终端设置', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: notifier.reset,
                  child: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 字号
            Row(
              children: [
                Text('字体大小', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  settings.fontSize.toStringAsFixed(0),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: '减小字号',
                  onPressed: settings.fontSize > TerminalSettings.minFontSize
                      ? notifier.decreaseFontSize
                      : null,
                  icon: const Icon(Icons.text_decrease),
                ),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: TerminalSettings.minFontSize,
                    max: TerminalSettings.maxFontSize,
                    divisions:
                        (TerminalSettings.maxFontSize - TerminalSettings.minFontSize)
                            .round(),
                    label: settings.fontSize.toStringAsFixed(0),
                    onChanged: notifier.setFontSize,
                  ),
                ),
                IconButton(
                  tooltip: '增大字号',
                  onPressed: settings.fontSize < TerminalSettings.maxFontSize
                      ? notifier.increaseFontSize
                      : null,
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                r'root@acepanel:~# echo 预览 12345',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: settings.fontSize,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.showKeyboardBar,
              onChanged: notifier.setShowKeyboardBar,
              title: const Text('显示快捷键条'),
              subtitle: const Text('Esc / Tab / 方向键 / Ctrl 组合键'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.autoReconnect,
              onChanged: notifier.setAutoReconnect,
              title: const Text('断线后自动重连一次'),
              subtitle: const Text('仅对已成功连接过的会话生效'),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Text('回滚行数', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${settings.scrollback}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.scrollback.toDouble(),
              min: TerminalSettings.minScrollback.toDouble(),
              max: TerminalSettings.maxScrollback.toDouble(),
              divisions: 39,
              label: '${settings.scrollback}',
              onChanged: (value) => notifier.setScrollback(value.round()),
            ),
            Text(
              '回滚行数在下次打开终端时生效。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
