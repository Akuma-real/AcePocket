import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/version/panel_feature.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feature_gate.dart';
import '../models/webhook.dart';
import '../providers/notify_alert_providers.dart';
import '../widgets/form_fields.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/snack.dart';
import '../widgets/webhook_tile.dart';

/// WebHook 列表页 `/webhooks`。
class WebhookPage extends ConsumerStatefulWidget {
  const WebhookPage({super.key});

  @override
  ConsumerState<WebhookPage> createState() => _WebhookPageState();
}

class _WebhookPageState extends ConsumerState<WebhookPage> {
  int? _busyId;

  Future<void> _reloadQuietly() async {
    try {
      await ref.read(webhooksProvider.notifier).reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _runBusy(int id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _create() async {
    await context.push('/webhooks/new');
    if (!mounted) return;
    await _reloadQuietly();
  }

  Future<void> _edit(WebHook webhook) async {
    await context.push('/webhooks/${webhook.id}/edit');
    if (!mounted) return;
    await _reloadQuietly();
  }

  Future<void> _toggle(WebHook webhook) async {
    await _runBusy(webhook.id, () async {
      await ref
          .read(notifyAlertRepoProvider)
          .updateWebhook(webhook.copyWith(status: !webhook.status));
      if (mounted) {
        showSnack(context, webhook.status ? 'WebHook 已停用' : 'WebHook 已启用');
      }
      await _reloadQuietly();
    });
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showSnack(context, '回调地址已复制');
  }

  Future<void> _delete(WebHook webhook) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除 WebHook',
      content: '确定要删除「${webhook.name.isEmpty ? '未命名 WebHook' : webhook.name}」吗？'
          '删除后回调地址立即失效，对应脚本文件也会被移除。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    await _runBusy(webhook.id, () async {
      await ref.read(notifyAlertRepoProvider).deleteWebhook(webhook.id);
      if (mounted) showSnack(context, '已删除');
      await _reloadQuietly();
    });
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(webhooksProvider.notifier).loadMore();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webhooksProvider);
    final baseUrl = ref.watch(webhookBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebHook'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(webhooksProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const FeatureUnsupportedBanner(feature: PanelFeature.webhook),
          Expanded(
            child: NotifyPagedListView<WebHook>(
              state: state,
              header: const InfoBanner(
                text: '每个 WebHook 对应一个回调地址，GET / POST 请求该地址即以指定系统用户'
                    '执行脚本。地址中的 Key 等同于凭据，请妥善保管。',
              ),
              onRefresh: () => ref.read(webhooksProvider.notifier).refresh(),
              onLoadMore: _loadMore,
              onRetry: () => ref.invalidate(webhooksProvider),
              emptyMessage: '暂无 WebHook',
              emptyIcon: Icons.webhook_outlined,
              itemBuilder: (context, webhook, index) => WebHookTile(
                webhook: webhook,
                callbackUrl: '$baseUrl${webhook.key}',
                busy: _busyId == webhook.id,
                onEdit: () => _edit(webhook),
                onToggle: () => _toggle(webhook),
                onCopyUrl: () => _copyUrl('$baseUrl${webhook.key}'),
                onDelete: () => _delete(webhook),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新建 WebHook'),
      ),
    );
  }
}
