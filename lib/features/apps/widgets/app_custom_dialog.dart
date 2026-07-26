import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/app_custom.dart';
import '../models/app_item.dart';
import '../providers/apps_providers.dart';

/// 自定义编译参数编辑对话框（仅源码编译类应用支持）。
///
/// 读取 `GET /api/app/custom`，保存 `POST /api/app/custom`。
/// 保存成功返回 true。
Future<bool> showAppCustomDialog(
  BuildContext context, {
  required AppItem app,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AppCustomDialog(app: app),
  );
  return result ?? false;
}

class _AppCustomDialog extends ConsumerStatefulWidget {
  const _AppCustomDialog({required this.app});

  final AppItem app;

  @override
  ConsumerState<_AppCustomDialog> createState() => _AppCustomDialogState();
}

class _AppCustomDialogState extends ConsumerState<_AppCustomDialog> {
  final _preScriptController = TextEditingController();
  final _argsController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _preScriptController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(appsRepoProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      await repo.saveCustom(
        widget.app.slug,
        AppCustom(
          preScript: _preScriptController.text,
          args: _argsController.text,
        ),
      );
      if (!mounted) return;
      ref.invalidate(appCustomProvider(widget.app.slug));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(appCustomProvider(widget.app.slug));

    return AlertDialog(
      title: Text('${widget.app.name} 编译参数'),
      content: SizedBox(
        width: double.maxFinite,
        child: async.when(
          loading: () => const SizedBox(
            height: 140,
            child: LoadingView(message: '读取中…'),
          ),
          error: (error, _) => SizedBox(
            height: 180,
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(appCustomProvider(widget.app.slug)),
            ),
          ),
          data: (custom) {
            if (!_initialized) {
              _initialized = true;
              _preScriptController.text = custom.preScript;
              _argsController.text = custom.args;
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '前置脚本在 configure 之前执行，编译参数会追加到 configure 末尾。'
                    '修改后需重新安装应用才会生效。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _preScriptController,
                    minLines: 3,
                    maxLines: 6,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: '前置脚本',
                      hintText: '#!/bin/bash\n…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _argsController,
                    minLines: 2,
                    maxLines: 5,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: '编译参数',
                      hintText: '--with-http_v2_module …',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: (_saving || !async.hasValue) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
