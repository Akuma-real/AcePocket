import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/section_card.dart';
import '../providers/settings_providers.dart';

/// 面板便签（`GET/POST /api/setting/memo`）。
///
/// 草稿状态通过 [onDirtyChanged] 上报给宿主页面，由页面统一做返回拦截——
/// 否则用户写了半屏便签后侧滑返回会静默丢失。
class MemoCard extends ConsumerStatefulWidget {
  const MemoCard({super.key, this.onDirtyChanged});

  /// 便签是否存在未保存修改发生变化时回调。
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends ConsumerState<MemoCard> {
  final TextEditingController _controller = TextEditingController();

  /// 服务端当前内容（保存成功后同步更新）。
  String _loaded = '';
  bool _initialized = false;
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 重算草稿状态并上报（仅在翻转时通知，避免每个按键都惊动父级）。
  void _refreshDirty() {
    final dirty = _controller.text != _loaded;
    if (dirty == _dirty) return;
    setState(() => _dirty = dirty);
    widget.onDirtyChanged?.call(dirty);
  }

  /// 用服务端返回的内容刷新输入框。
  ///
  /// 已有本地草稿时不覆盖——用户正在输入的内容优先于后台刷新。
  void _adopt(String memo) {
    if (_initialized && (_dirty || memo == _loaded)) return;
    _initialized = true;
    _loaded = memo;
    _controller.text = memo;
    _refreshDirty();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text;
    setState(() => _saving = true);
    try {
      await ref.read(settingRepoProvider).updateMemo(text);
      _loaded = text;
      _refreshDirty();
      if (!mounted) return;
      showSuccessSnack(context, '便签已保存');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 刷新 / 切换服务器后 provider 会推送新内容，在 build 之外同步进输入框，
    // 否则输入框会一直停留在首次加载时的旧内容上。
    ref.listen<AsyncValue<String>>(panelMemoProvider, (_, next) {
      next.whenData(_adopt);
    });
    final memoAsync = ref.watch(panelMemoProvider);

    return memoAsync.when(
      loading: () => const SectionCard(
        title: '便签',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (error, _) => SectionCard(
        title: '便签',
        child: Row(
          children: [
            Expanded(
              child: Text(
                describeError(error),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(panelMemoProvider),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
      data: (memo) {
        // 首帧同步：此时下方 TextField 尚未创建，直接写 controller 是安全的；
        // 后续更新一律走上面的 ref.listen。
        if (!_initialized) _adopt(memo);
        return SectionCard(
          title: '便签',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 3,
                onChanged: (_) => _refreshDirty(),
                decoration: const InputDecoration(
                  hintText: '记录一些临时信息，保存后在面板首页可见',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: (_saving || !_dirty) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中…' : '保存便签'),
                ),
              ),
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '便签有未保存的修改',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
