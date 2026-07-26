import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/file_item.dart';
import '../providers/files_providers.dart';

/// 文本文件编辑器：读取（`GET /api/file/content`）与保存（`POST /api/file/save`）。
///
/// 面板对超过 10MB 的文件拒绝返回内容，此时展示错误并提示下载查看。
class FileEditorPage extends ConsumerStatefulWidget {
  const FileEditorPage({super.key, required this.path});

  /// 待编辑文件的绝对路径。
  final String path;

  @override
  ConsumerState<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends ConsumerState<FileEditorPage> {
  final TextEditingController _controller = TextEditingController();

  /// 已载入的原始内容，用于判断是否有未保存修改。
  String _original = '';
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  /// 是否自动换行（关闭时横向滚动，适合配置文件）。
  bool _wrap = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    final dirty = _controller.text != _original;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _applyContent(FileContent content) {
    // 首次加载或用户主动重载后回填内容，避免 build 期间覆盖用户输入。
    if (_loaded) return;
    _loaded = true;
    _original = content.text;
    _controller.text = content.text;
    _dirty = false;
  }

  Future<void> _reload() async {
    if (_dirty) {
      final ok = await showConfirmDialog(
        context,
        title: '放弃修改',
        content: '重新加载会丢失当前未保存的修改，是否继续？',
        confirmText: '重新加载',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() {
      _loaded = false;
      _dirty = false;
    });
    ref.invalidate(fileContentProvider(widget.path));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(fileRepoProvider)
          .save(widget.path, _controller.text);
      if (!mounted) return;
      setState(() {
        _original = _controller.text;
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // describeError：非 ApiException 时避免露出原始英文异常。
      _showError(describeError(e));
    }
  }

  void _showError(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.errorContainer,
        showCloseIcon: true,
      ));
  }

  Future<void> _confirmLeave() async {
    final ok = await showConfirmDialog(
      context,
      title: '放弃修改',
      content: '「${posixBaseName(widget.path)}」有未保存的修改，确定要离开吗？',
      confirmText: '放弃',
      danger: true,
    );
    if (!ok || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/files');
    }
  }

  Widget _buildEditor(FileContent content) {
    final theme = Theme.of(context);
    final editor = TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
        isDense: false,
      ),
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                content.mime.isEmpty ? '未知类型' : content.mime.split(';').first,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!content.looksLikeText)
          Material(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 18,
                      color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '该文件可能不是文本文件，保存后可能损坏原内容，请谨慎操作。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _wrap
              ? editor
              : Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      // 关闭自动换行时给编辑区一个足够宽的画布，横向滚动查看长行。
                      width: MediaQuery.of(context).size.width * 3,
                      child: editor,
                    ),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: theme.colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => Text(
                    '${value.text.length} 字符',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (_dirty)
                  Text(
                    '未保存',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(fileContentProvider(widget.path));

    contentAsync.whenData(_applyContent);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            posixBaseName(widget.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: '复制路径',
              icon: const Icon(Icons.link),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.path));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('路径已复制到剪贴板')),
                );
              },
            ),
            IconButton(
              tooltip: _wrap ? '关闭自动换行' : '开启自动换行',
              icon: Icon(_wrap ? Icons.wrap_text : Icons.notes),
              onPressed: () => setState(() => _wrap = !_wrap),
            ),
            IconButton(
              tooltip: '重新加载',
              icon: const Icon(Icons.refresh),
              onPressed: _saving ? null : _reload,
            ),
            IconButton(
              tooltip: '保存',
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.save_outlined),
              onPressed: _saving || !_loaded ? null : _save,
            ),
          ],
        ),
        body: contentAsync.when(
          loading: () => const LoadingView(message: '正在读取文件…'),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(fileContentProvider(widget.path)),
          ),
          data: _buildEditor,
        ),
      ),
    );
  }
}
