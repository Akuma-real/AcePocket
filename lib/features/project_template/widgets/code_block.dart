import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snack.dart';

/// 只读代码块：等宽字体、横向可滚动、可一键复制。
///
/// 用于展示模板的 docker compose 内容。
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.maxHeight = 360,
    this.copyLabel = '复制内容',
  });

  final String code;
  final double maxHeight;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code.isEmpty ? '（内容为空）' : code,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: code.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) showSnack(context, '已复制到剪贴板');
                  },
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: Text(copyLabel),
          ),
        ),
      ],
    );
  }
}
