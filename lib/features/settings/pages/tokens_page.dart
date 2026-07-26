import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/panel_user.dart';
import '../models/user_token.dart';
import '../providers/settings_providers.dart';
import '../providers/tokens_providers.dart';
import '../widgets/list_footer.dart';
import '../widgets/token_dialogs.dart';
import '../widgets/token_tile.dart';

/// API 令牌管理页（`/api/user_tokens`）。
///
/// 令牌按用户隔离，这里展示当前 API 令牌所属用户（`GET /api/user/info`）的全部令牌。
class TokensPage extends ConsumerStatefulWidget {
  const TokensPage({super.key});

  @override
  ConsumerState<TokensPage> createState() => _TokensPageState();
}

class _TokensPageState extends ConsumerState<TokensPage> {
  final ScrollController _scrollController = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(tokenListProvider.notifier).loadMore();
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _create() async {
    final PanelUser user;
    try {
      user = await ref.read(currentUserProvider.future);
    } catch (e) {
      _toast('获取当前用户失败：${_errorText(e)}');
      return;
    }
    if (!mounted) return;
    final result = await showTokenEditorDialog(context);
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final token = await ref.read(tokenRepoProvider).create(
            userId: user.id,
            ips: result.ips,
            expiredAt: result.expiredAt,
          );
      await ref.read(tokenListProvider.notifier).reload();
      if (!mounted) return;
      await showTokenCreatedDialog(context, token);
    } catch (e) {
      _toast('创建失败：${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(UserToken token) async {
    final result = await showTokenEditorDialog(context, token: token);
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(tokenRepoProvider).update(
            id: token.id,
            ips: result.ips,
            expiredAt: result.expiredAt,
          );
      await ref.read(tokenListProvider.notifier).reload();
      _toast('令牌 #${token.id} 已更新');
    } catch (e) {
      _toast('更新失败：${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(UserToken token, bool inUse) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除令牌',
      content: '确定要删除令牌 #${token.id} 吗？删除后使用该令牌的调用方将立即失效。'
          '${inUse ? '\n\n警告：这是本 App 当前正在使用的令牌，删除后将无法继续连接该服务器！' : ''}',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await ref.read(tokenRepoProvider).delete(token.id);
      await ref.read(tokenListProvider.notifier).reload();
      _toast('令牌 #${token.id} 已删除');
    } catch (e) {
      _toast('删除失败：${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listAsync = ref.watch(tokenListProvider);
    final userAsync = ref.watch(currentUserProvider);
    final server = ref.watch(activeServerProvider);
    final currentTokenId = int.tryParse(server?.tokenId ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 令牌'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tokenListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('创建令牌'),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userAsync.when(
                      loading: () => '正在获取当前用户…',
                      error: (e, _) => '当前用户获取失败：${_errorText(e)}',
                      data: (user) =>
                          '当前用户：${user.username.isEmpty ? '#${user.id}' : user.username}'
                          '（令牌按用户隔离）',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingView(message: '正在加载令牌列表…'),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(tokenListProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tokenListProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: EmptyView(
                            message: '还没有创建任何 API 令牌',
                            icon: Icons.vpn_key_outlined,
                            action: FilledButton.icon(
                              onPressed: _busy ? null : _create,
                              icon: const Icon(Icons.add),
                              label: const Text('创建令牌'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(tokenListProvider.notifier).refresh();
                    } catch (e) {
                      _toast('刷新失败：${_errorText(e)}');
                    }
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 96),
                    itemCount: state.items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return ListFooter(
                          loading: state.loadingMore,
                          hasMore: state.hasMore,
                          total: state.total,
                        );
                      }
                      final token = state.items[index];
                      final inUse = currentTokenId != null &&
                          currentTokenId == token.id;
                      return TokenTile(
                        token: token,
                        inUse: inUse,
                        onEdit: () => _edit(token),
                        onDelete: () => _delete(token, inUse),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
