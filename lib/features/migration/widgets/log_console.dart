import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/section_card.dart';
import 'snack.dart';

/// 迁移日志控制台：等宽字体、自动滚动到底部、一键复制。
class LogConsole extends StatefulWidget {
  const LogConsole({
    super.key,
    required this.logs,
    this.title = '迁移日志',
    this.running = false,
    this.height = 300,
    this.emptyText = '暂无日志',
  });

  final List<String> logs;
  final String title;

  /// 迁移进行中：底部展示等待提示。
  final bool running;

  final double height;
  final String emptyText;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _controller = ScrollController();

  /// 用户手动上滑查看历史时暂停自动滚动。
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) _scheduleScroll();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final atBottom = position.pixels >= position.maxScrollExtent - 24;
    if (atBottom != _autoScroll) setState(() => _autoScroll = atBottom);
  }

  void _scheduleScroll() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.logs.join('\n')));
    if (!mounted) return;
    showSnack(context, '已复制 ${widget.logs.length} 行日志');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SectionCard(
      title: '${widget.title}（${widget.logs.length} 行）',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_autoScroll)
            IconButton(
              tooltip: '回到底部',
              icon: const Icon(Icons.vertical_align_bottom, size: 20),
              onPressed: () {
                setState(() => _autoScroll = true);
                _scheduleScroll();
              },
            ),
          IconButton(
            tooltip: '复制全部日志',
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            onPressed: widget.logs.isEmpty ? null : _copy,
          ),
        ],
      ),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.logs.isEmpty
            ? Center(
                child: Text(
                  widget.running ? '等待面板输出日志…' : widget.emptyText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Scrollbar(
                controller: _controller,
                child: ListView.builder(
                  controller: _controller,
                  itemCount: widget.logs.length + (widget.running ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= widget.logs.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '迁移进行中…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
                        widget.logs[index],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.35,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
