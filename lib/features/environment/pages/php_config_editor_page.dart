import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../providers/environment_providers.dart';
import '../widgets/environment_ui.dart';

/// PHP 配置文件编辑页（`/environments/php/:version/config?target=ini|fpm`）。
///
/// - `ini`：`GET/POST /environment/php/{version}/config`（php.ini）
/// - `fpm`：`GET/POST /environment/php/{version}/fpm_config`（php-fpm.conf）
class PhpConfigEditorPage extends ConsumerStatefulWidget {
  const PhpConfigEditorPage({
    super.key,
    required this.version,
    required this.fpm,
  });

  final int version;

  /// true 编辑 php-fpm.conf，false 编辑 php.ini。
  final bool fpm;

  @override
  ConsumerState<PhpConfigEditorPage> createState() =>
      _PhpConfigEditorPageState();
}

class _PhpConfigEditorPageState extends ConsumerState<PhpConfigEditorPage> {
  final TextEditingController _controller = TextEditingController();

  /// 已载入的服务端原文，用于判断是否有未保存修改。
  String? _loaded;
  bool _saving = false;

  String get _fileName => widget.fpm ? 'php-fpm.conf' : 'php.ini';

  AutoDisposeFutureProvider<String> get _provider => widget.fpm
      ? phpFpmConfigProvider(widget.version)
      : phpIniProvider(widget.version);

  @override
  void initState() {
    super.initState();
    // provider 已有缓存值时（页面返回复用）直接填充，避免编辑器空白。
    final cached = ref.read(_provider).valueOrNull;
    if (cached != null) {
      _controller.text = cached;
      _loaded = cached;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _loaded != null && _controller.text != _loaded;

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(environmentRepoProvider);
    final content = _controller.text;
    try {
      if (widget.fpm) {
        await repo.updatePhpFpmConfig(widget.version, content);
      } else {
        await repo.updatePhpConfig(widget.version, content);
      }
      setState(() => _loaded = content);
      ref.invalidate(_provider);
      ref.invalidate(phpConfigTuneProvider(widget.version));
      if (!mounted) return;
      showEnvSnack(context, '$_fileName 已保存，需重启 PHP-FPM 后生效');
    } catch (e) {
      if (!mounted) return;
      showEnvSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reload() async {
    if (_dirty) {
      final ok = await showConfirmDialog(
        context,
        title: '放弃未保存的修改？',
        content: '重新载入会丢弃当前编辑内容。',
        confirmText: '重新载入',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _loaded = null);
    ref.invalidate(_provider);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(_provider);
    final theme = Theme.of(context);

    // 数据到达（或重新载入）时填充编辑器。
    ref.listen<AsyncValue<String>>(_provider, (previous, next) {
      next.whenData((value) {
        if (_loaded == null) {
          _controller.text = value;
          setState(() => _loaded = value);
        }
      });
    });

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showConfirmDialog(
          context,
          title: '放弃未保存的修改？',
          content: '$_fileName 的修改尚未保存。',
          confirmText: '放弃',
          danger: true,
        );
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('$_fileName · PHP ${widget.version}'),
          actions: [
            IconButton(
              tooltip: '重新载入',
              icon: const Icon(Icons.refresh),
              onPressed: _saving ? null : _reload,
            ),
            TextButton(
              onPressed: _saving || !config.hasValue ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: config.when(
          loading: () => LoadingView(message: '读取 $_fileName…'),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(_provider),
          ),
          data: (_) => Column(
            children: [
              HintBanner(
                '直接修改 $_fileName 原文，若不清楚各参数含义请改用「参数调优」页面。'
                '保存后需重启 php-fpm-${widget.version} 服务才会生效。',
                warning: true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
