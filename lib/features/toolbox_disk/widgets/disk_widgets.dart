import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';

/// 把异常转成可直接展示的文案（[ApiException] 取面板返回的 msg）。
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
}

/// 统一的顶部提示（成功 / 失败）。
void showSnack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: error ? theme.colorScheme.onErrorContainer : null,
          ),
        ),
        backgroundColor: error ? theme.colorScheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

/// 字节数格式化（1024 进制，与面板 Web 端 formatBytes 表现一致）。
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final text = index == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text ${units[index]}';
}

/// 只读信息行：左标题右取值。
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
    this.labelWidth = 92,
  });

  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小标签（分区类型 / 文件系统 / 状态等）。
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: base),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: base),
          ),
        ],
      ),
    );
  }
}

/// 使用率进度条：>90% 红、>70% 橙、其余主色。
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.percent, this.width});

  final int percent;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = percent.clamp(0, 100);
    final color = clamped > 90
        ? theme.colorScheme.error
        : clamped > 70
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: clamped / 100,
        minHeight: 6,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
    return Row(
      children: [
        Expanded(child: width == null ? bar : SizedBox(width: width, child: bar)),
        const SizedBox(width: 8),
        Text(
          '$clamped%',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// 页面内的提示条（警告 / 说明）。
class NoticeBar extends StatelessWidget {
  const NoticeBar({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.danger = false,
  });

  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg =
        danger ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurfaceVariant;
    final bg = danger
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表内的小型加载遮罩（操作执行中）。
class BusyIndicator extends StatelessWidget {
  const BusyIndicator({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
}
