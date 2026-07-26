import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snack.dart';

/// 查看证书 / 私钥内容（PEM），支持一键复制。
Future<void> showCertContentDialog(
  BuildContext context, {
  required String cert,
  required String key,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CertContentDialog(cert: cert, key2: key),
  );
}

class _CertContentDialog extends StatefulWidget {
  const _CertContentDialog({required this.cert, required this.key2});

  final String cert;
  final String key2;

  @override
  State<_CertContentDialog> createState() => _CertContentDialogState();
}

class _CertContentDialogState extends State<_CertContentDialog> {
  int _tab = 0;

  String get _current => _tab == 0 ? widget.cert : widget.key2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: const Text('证书内容'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: size.width,
        height: size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('证书')),
                ButtonSegment(value: 1, label: Text('私钥')),
              ],
              selected: {_tab},
              onSelectionChanged: (values) =>
                  setState(() => _tab = values.first),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _current.isEmpty ? '（空）' : _current,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _current.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _current));
                  if (!context.mounted) return;
                  showSnack(context, _tab == 0 ? '证书已复制' : '私钥已复制');
                },
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('复制'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
