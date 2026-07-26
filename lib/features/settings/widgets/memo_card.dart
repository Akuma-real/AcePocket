import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/section_card.dart';
import '../providers/settings_providers.dart';

/// 面板便签（`GET/POST /api/setting/memo`）。
class MemoCard extends ConsumerStatefulWidget {
  const MemoCard({super.key});

  @override
  ConsumerState<MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends ConsumerState<MemoCard> {
  final TextEditingController _controller = TextEditingController();
  String _loaded = '';
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingRepoProvider).updateMemo(_controller.text);
      _loaded = _controller.text;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('便签已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : '保存失败：$e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                error is ApiException ? error.message : '$error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(panelMemoProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (memo) {
        if (!_initialized) {
          _initialized = true;
          _loaded = memo;
          _controller.text = memo;
        }
        return SectionCard(
          title: '便签',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '记录一些临时信息，保存后在面板首页可见',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _saving ? null : _save,
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
              if (_controller.text != _loaded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '有未保存的修改',
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
