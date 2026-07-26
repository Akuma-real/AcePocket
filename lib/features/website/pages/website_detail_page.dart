import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/lv_option.dart';
import '../models/website.dart';
import '../models/website_setting.dart';
import '../providers/website_providers.dart';
import '../widgets/custom_config_list_field.dart';
import '../widgets/delete_website_dialog.dart';
import '../widgets/formatters.dart';
import '../widgets/kv_list_field.dart';
import '../widgets/listen_list_field.dart';
import '../widgets/proxy_list_field.dart';
import '../widgets/redirect_list_field.dart';
import '../widgets/snack.dart';
import '../widgets/string_list_field.dart';

/// 网站详情与配置页 `/websites/:id`。
///
/// 配置项按面板 `web/src/views/website/EditModal.vue` 的分组拆成多个 tab：
/// 常规、域名与监听、HTTPS、伪静态（PHP）、反向代理（proxy）、重定向、高级。
/// 顶部「保存」统一提交 `PUT /api/website/{id}`（`request.WebsiteUpdate`）；
/// 运行状态、备注、到期时间为独立接口，修改后立即生效。
class WebsiteDetailPage extends ConsumerStatefulWidget {
  const WebsiteDetailPage({super.key, required this.websiteId});

  final int websiteId;

  @override
  ConsumerState<WebsiteDetailPage> createState() => _WebsiteDetailPageState();
}

class _WebsiteDetailPageState extends ConsumerState<WebsiteDetailPage> {
  WebsiteSetting? _setting;

  /// 网站列表行（状态 / 备注 / 到期时间等基础信息，面板无单条接口，翻页查找）。
  Website? _row;

  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _statusBusy = false;
  bool _remarkBusy = false;
  bool _expireBusy = false;
  bool _obtainBusy = false;
  bool _certBusy = false;

  /// 每次成功加载后自增，用于强制重建各列表编辑器的内部状态。
  int _revision = 0;

  final _pathController = TextEditingController();
  final _rootController = TextEditingController();
  final _accessLogController = TextEditingController();
  final _errorLogController = TextEditingController();
  final _rewriteController = TextEditingController();
  final _sslCertController = TextEditingController();
  final _sslKeyController = TextEditingController();
  final _remarkController = TextEditingController();

  static const _tlsProtocols = <({String value, String label})>[
    (value: 'TLSv1', label: 'TLS 1.0'),
    (value: 'TLSv1.1', label: 'TLS 1.1'),
    (value: 'TLSv1.2', label: 'TLS 1.2'),
    (value: 'TLSv1.3', label: 'TLS 1.3'),
  ];

  static const _realIpHeaders = [
    'X-Real-IP',
    'X-Forwarded-For',
    'CF-Connecting-IP',
    'True-Client-IP',
    'Ali-Cdn-Real-Ip',
    'EO-Connecting-IP',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _rootController.dispose();
    _accessLogController.dispose();
    _errorLogController.dispose();
    _rewriteController.dispose();
    _sslCertController.dispose();
    _sslKeyController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(websiteRepoProvider);
      final setting = await repo.getSetting(widget.websiteId);
      Website? row;
      try {
        row = await repo.findRow(widget.websiteId);
      } catch (_) {
        // 基础信息获取失败不阻断配置编辑。
        row = null;
      }
      if (!mounted) return;
      setState(() {
        _setting = setting;
        _row = row;
        _loading = false;
        _dirty = false;
        _revision++;
        _pathController.text = setting.path;
        _rootController.text = setting.root;
        _accessLogController.text = setting.accessLog;
        _errorLogController.text = setting.errorLog;
        _rewriteController.text = setting.rewrite;
        _sslCertController.text = setting.sslCert;
        _sslKeyController.text = setting.sslKey;
        _remarkController.text = row?.remark ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  /// 与面板前端一致：开启 HTTPS 时自动补 443 监听，关闭时移除全部 SSL 监听。
  void _syncSslListens(WebsiteSetting setting, bool isNginx) {
    if (setting.ssl) {
      if (!setting.listens.any((l) => l.https)) {
        final args = <String>['ssl', if (isNginx) 'quic'];
        if (setting.listens.any((l) => l.address.startsWith('[::]'))) {
          setting.listens
              .add(ListenConfig(address: '[::]:443', args: [...args]));
        }
        setting.listens.add(ListenConfig(address: '443', args: [...args]));
      }
    } else {
      setting.listens.removeWhere((l) =>
          l.address == '443' ||
          l.address.endsWith(':443') ||
          l.https ||
          l.quic);
    }
  }

  Future<void> _save() async {
    final setting = _setting;
    if (setting == null) return;

    if (setting.domains.isEmpty) {
      showSnack(context, '请至少保留一个域名', error: true);
      return;
    }
    if (setting.listens.isEmpty) {
      showSnack(context, '请至少保留一个监听地址', error: true);
      return;
    }
    if (setting.path.isEmpty || !setting.path.startsWith('/')) {
      showSnack(context, '网站目录需为绝对路径', error: true);
      return;
    }
    if (setting.root.isEmpty || !setting.root.startsWith('/')) {
      showSnack(context, '运行目录需为绝对路径', error: true);
      return;
    }
    if (setting.index.isEmpty) {
      showSnack(context, '请至少保留一个默认文档', error: true);
      return;
    }
    if (setting.ssl &&
        (setting.sslCert.trim().isEmpty || setting.sslKey.trim().isEmpty)) {
      showSnack(context, '开启 HTTPS 需要填写证书与私钥', error: true);
      return;
    }

    final isNginx =
        ref.read(installedEnvironmentProvider).valueOrNull?.isNginx ?? true;
    _syncSslListens(setting, isNginx);

    setState(() => _saving = true);
    try {
      await ref.read(websiteRepoProvider).updateSetting(setting);
      if (!mounted) return;
      showSnack(context, '配置已保存');
      ref.invalidate(websiteListProvider);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetConfig() async {
    final ok = await showConfirmDialog(
      context,
      title: '重置配置',
      content: '将把该网站的配置文件恢复为面板默认模板，自定义修改会丢失。确定继续吗？',
      confirmText: '重置',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(websiteRepoProvider).resetConfig(widget.websiteId);
      if (!mounted) return;
      showSnack(context, '配置已重置');
      ref.invalidate(websiteListProvider);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _toggleStatus(bool value) async {
    setState(() => _statusBusy = true);
    try {
      await ref.read(websiteRepoProvider).updateStatus(widget.websiteId, value);
      if (!mounted) return;
      setState(() => _row = _row?.copyWith(status: value));
      showSnack(context, value ? '已启用网站' : '已停用网站');
      ref.invalidate(websiteListProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _saveRemark() async {
    setState(() => _remarkBusy = true);
    try {
      await ref
          .read(websiteRepoProvider)
          .updateRemark(widget.websiteId, _remarkController.text.trim());
      if (!mounted) return;
      showSnack(context, '备注已保存');
      ref.invalidate(websiteListProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _remarkBusy = false);
    }
  }

  Future<void> _pickExpireAt() async {
    final now = DateTime.now();
    final current = parsePanelTime(_row?.expireAt) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    await _updateExpireAt(formatExpireAtPayload(picked));
  }

  Future<void> _updateExpireAt(String payload) async {
    setState(() => _expireBusy = true);
    try {
      await ref
          .read(websiteRepoProvider)
          .updateExpireAt(widget.websiteId, payload);
      if (!mounted) return;
      showSnack(context, payload.isEmpty ? '已设为不限时' : '到期时间已更新');
      ref.invalidate(websiteListProvider);
      final row = await ref.read(websiteRepoProvider).findRow(widget.websiteId);
      if (!mounted) return;
      setState(() => _row = row ?? _row);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _expireBusy = false);
    }
  }

  /// 仅更新网站证书文件（`POST /api/website/cert`）。
  ///
  /// 与「保存配置」不同：面板只把证书与私钥写入
  /// `sites/<name>/config/{fullchain.pem,private.key}`，网站已启用 SSL 时顺带
  /// 重载 Web 服务器，不会改动监听、域名等其他配置。
  Future<void> _updateCertOnly() async {
    final setting = _setting;
    if (setting == null) return;
    final cert = _sslCertController.text.trim();
    final key = _sslKeyController.text.trim();
    if (cert.isEmpty || key.isEmpty) {
      showSnack(context, '请先填写证书与私钥内容', error: true);
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '仅更新证书文件？',
      content: '将把当前填写的证书与私钥直接写入网站「${setting.name}」的证书文件。'
          '${setting.ssl ? '该网站已启用 HTTPS，面板会立即重载 Web 服务器。' : '该网站尚未启用 HTTPS，证书写入后不会立即生效。'}\n\n'
          '本操作不会提交本页的其他修改。',
      confirmText: '更新证书',
    );
    if (!ok) return;

    setState(() => _certBusy = true);
    try {
      await ref.read(websiteRepoProvider).updateCert(
            name: setting.name,
            cert: cert,
            key: key,
          );
      if (!mounted) return;
      showSnack(context, '证书已更新');
      ref.invalidate(websiteCertListProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _certBusy = false);
    }
  }

  Future<void> _obtainCert() async {
    final setting = _setting;
    if (setting == null) return;
    final hasWildcard = setting.domains.any((d) => d.contains('*'));
    int? dnsId;

    if (hasWildcard) {
      List<DnsItem> dnsList;
      try {
        dnsList = await ref.read(websiteDnsListProvider.future);
      } catch (e) {
        if (mounted) showErrorSnack(context, e);
        return;
      }
      if (!mounted) return;
      if (dnsList.isEmpty) {
        showSnack(
          context,
          '网站包含泛域名，需要 DNS 验证，请先在证书管理中添加 DNS 账号',
          error: true,
        );
        return;
      }
      dnsId = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择 DNS 账号'),
          children: [
            for (final dns in dnsList)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(dns.id),
                child: Text('${dns.name}（${dns.type}）'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      if (dnsId == null) return;
    }

    if (!mounted) return;
    setState(() => _obtainBusy = true);
    showSnack(context, '正在签发证书，请稍候…');
    try {
      await ref
          .read(websiteRepoProvider)
          .obtainCert(widget.websiteId, dnsId: dnsId);
      if (!mounted) return;
      showSnack(context, '证书签发成功');
      ref.invalidate(websiteListProvider);
      ref.invalidate(websiteCertListProvider);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _obtainBusy = false);
    }
  }

  Future<void> _delete() async {
    final name = _setting?.name ?? _row?.name ?? '该网站';
    final options = await showDeleteWebsiteDialog(context, websiteName: name);
    if (options == null) return;
    try {
      await ref.read(websiteRepoProvider).delete(
            widget.websiteId,
            deletePath: options.deletePath,
            deleteDb: options.deleteDb,
          );
      if (!mounted) return;
      showSnack(context, '已删除网站 $name');
      ref.invalidate(websiteListProvider);
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/websites');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return showConfirmDialog(
      context,
      title: '放弃修改',
      content: '当前配置尚未保存，返回后修改将丢失。确定放弃吗？',
      confirmText: '放弃',
      danger: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setting = _setting;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('网站配置')),
        body: const LoadingView(message: '正在加载网站配置…'),
      );
    }
    if (setting == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('网站配置')),
        body: ErrorView(error: _error ?? '加载失败', onRetry: _load),
      );
    }

    final tabs = <({String label, Widget Function() builder})>[
      (label: '常规', builder: _buildGeneralTab),
      (label: '域名与监听', builder: _buildDomainTab),
      (label: 'HTTPS', builder: _buildHttpsTab),
      if (setting.type == 'php') (label: '伪静态', builder: _buildRewriteTab),
      if (setting.type == 'proxy')
        (label: '反向代理', builder: _buildProxyTab),
      (label: '重定向', builder: _buildRedirectTab),
      (label: '高级', builder: _buildAdvancedTab),
    ];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/websites');
          }
        }
      },
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(setting.name),
                Text(
                  '${_typeLabel(setting.type)}${_dirty ? ' · 有未保存的修改' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _dirty
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '访问统计',
                onPressed: () => context.push(
                  '/websites/${widget.websiteId}/stats',
                  extra: setting.name,
                ),
                icon: const Icon(Icons.bar_chart),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (value) {
                  switch (value) {
                    case 'reload':
                      _load();
                    case 'reset':
                      _resetConfig();
                    case 'delete':
                      _delete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reload',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh),
                      title: Text('重新加载'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.restart_alt),
                      title: Text('重置配置'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        '删除网站',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in tabs) Tab(text: tab.label)],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : '保存配置'),
          ),
          body: TabBarView(
            key: ValueKey(_revision),
            children: [for (final tab in tabs) tab.builder()],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'proxy' => '反向代理',
        'php' => 'PHP',
        'static' => '纯静态',
        _ => type,
      };

  Widget _tabBody(List<Widget> children) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        children: children,
      );

  // ---------------------------------------------------------------- 常规

  Widget _buildGeneralTab() {
    final setting = _setting!;
    final row = _row;
    final theme = Theme.of(context);
    final envAsync = ref.watch(installedEnvironmentProvider);
    final env = envAsync.valueOrNull ?? InstalledEnvironment.empty;

    return _tabBody([
      SectionCard(
        title: '运行状态',
        child: row == null
            ? Text(
                '未能获取网站运行状态（面板无单条网站信息接口，列表中未找到该网站）',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.status ? '运行中' : '已停用'),
                    subtitle: const Text('停用后访问该网站将返回停止页'),
                    value: row.status,
                    onChanged:
                        _statusBusy ? null : (v) => _toggleStatus(v),
                  ),
                  if (_statusBusy) const LinearProgressIndicator(),
                ],
              ),
      ),
      SectionCard(
        title: '基本信息',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoLine(label: '网站名称', value: setting.name),
            _InfoLine(label: '类型', value: _typeLabel(setting.type)),
            if (row != null) ...[
              _InfoLine(
                label: '创建时间',
                value: formatDateTime(row.createdAt),
              ),
              _InfoLine(label: '证书', value: row.certExpireLabel),
            ],
          ],
        ),
      ),
      SectionCard(
        title: '备注',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _remarkController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '便于识别该网站',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _remarkBusy ? null : _saveRemark,
                icon: const Icon(Icons.check),
                label: Text(_remarkBusy ? '保存中…' : '保存备注'),
              ),
            ),
          ],
        ),
      ),
      SectionCard(
        title: '到期时间',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row?.expireAt == null
                  ? '当前不限时'
                  : '当前到期时间：${formatDateTime(row!.expireAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _expireBusy ? null : _pickExpireAt,
                    icon: const Icon(Icons.event),
                    label: const Text('设置到期时间'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _expireBusy ? null : () => _updateExpireAt(''),
                    icon: const Icon(Icons.event_available),
                    label: const Text('设为不限时'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SectionCard(
        title: '目录',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: '网站目录',
                helperText: '绝对路径，如 /opt/ace/sites/example/public',
              ),
              onChanged: (v) {
                setting.path = v.trim();
                _markDirty();
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _rootController,
              decoration: const InputDecoration(
                labelText: '运行目录',
                helperText: 'Laravel 等框架需指向 public 目录',
              ),
              onChanged: (v) {
                setting.root = v.trim();
                _markDirty();
              },
            ),
            const SizedBox(height: 20),
            StringListField(
              label: '默认文档',
              initialValues: setting.index,
              minItems: 1,
              hintText: 'index.html',
              addButtonText: '添加默认文档',
              onChanged: (values) {
                setting.index = values;
                _markDirty();
              },
            ),
          ],
        ),
      ),
      if (setting.type == 'php')
        SectionCard(
          title: 'PHP',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (env.php.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: env.php.any((e) => e.value == setting.php)
                      ? setting.php
                      : null,
                  decoration: const InputDecoration(labelText: 'PHP 版本'),
                  items: [
                    for (final option in env.php)
                      DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => setting.php = v);
                    _markDirty();
                  },
                )
              else
                TextFormField(
                  initialValue: '${setting.php}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PHP 版本号',
                    helperText: '未能获取已安装版本列表，可直接填写版本号（如 84）',
                  ),
                  onChanged: (v) {
                    setting.php = int.tryParse(v.trim()) ?? 0;
                    _markDirty();
                  },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('防跨站攻击'),
                subtitle: const Text('open_basedir，限制 PHP 只能访问网站目录'),
                value: setting.openBasedir,
                onChanged: (v) {
                  setState(() => setting.openBasedir = v);
                  _markDirty();
                },
              ),
            ],
          ),
        ),
    ]);
  }

  // ------------------------------------------------------------ 域名与监听

  Widget _buildDomainTab() {
    final setting = _setting!;
    final isNginx =
        ref.watch(installedEnvironmentProvider).valueOrNull?.isNginx ?? true;

    return _tabBody([
      SectionCard(
        title: '域名',
        child: StringListField(
          label: '绑定域名',
          initialValues: setting.domains,
          minItems: 1,
          hintText: 'example.com',
          addButtonText: '添加域名',
          helperText: '支持泛域名（*.example.com），泛域名签发证书需 DNS 验证',
          onChanged: (values) {
            setting.domains = values;
            _markDirty();
          },
        ),
      ),
      SectionCard(
        title: '监听',
        child: ListenListField(
          listens: setting.listens,
          showQuic: isNginx,
          onChanged: _markDirty,
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- HTTPS

  Widget _buildHttpsTab() {
    final setting = _setting!;
    final theme = Theme.of(context);
    final certsAsync = ref.watch(websiteCertListProvider);

    return _tabBody([
      if (setting.ssl && setting.sslIssuer.isNotEmpty)
        SectionCard(
          title: '当前证书',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine(label: '颁发者', value: setting.sslIssuer),
              _InfoLine(
                label: '有效期',
                value: '${setting.sslNotBefore} ~ ${setting.sslNotAfter}',
              ),
              if (setting.sslDnsNames.isNotEmpty)
                _InfoLine(
                  label: '证书域名',
                  value: setting.sslDnsNames.join('、'),
                ),
            ],
          ),
        ),
      SectionCard(
        title: 'HTTPS 开关',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 HTTPS'),
              subtitle: const Text('保存时会自动补充 443 监听；关闭时移除全部 SSL 监听'),
              value: setting.ssl,
              onChanged: (v) {
                setState(() => setting.ssl = v);
                _markDirty();
              },
            ),
            if (setting.ssl) ...[
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('HSTS'),
                subtitle: const Text('强制浏览器仅使用 HTTPS 访问'),
                value: setting.hsts,
                onChanged: (v) {
                  setState(() => setting.hsts = v);
                  _markDirty();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('HTTP 强制跳转'),
                subtitle: const Text('http 请求 301 跳转到 https'),
                value: setting.httpRedirect,
                onChanged: (v) {
                  setState(() => setting.httpRedirect = v);
                  _markDirty();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('OCSP Stapling'),
                value: setting.ocsp,
                onChanged: (v) {
                  setState(() => setting.ocsp = v);
                  _markDirty();
                },
              ),
              const SizedBox(height: 8),
              Text('TLS 版本', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final protocol in _tlsProtocols)
                    FilterChip(
                      label: Text(protocol.label),
                      selected: setting.sslProtocols.contains(protocol.value),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!setting.sslProtocols
                                .contains(protocol.value)) {
                              setting.sslProtocols.add(protocol.value);
                            }
                          } else {
                            setting.sslProtocols.remove(protocol.value);
                          }
                        });
                        _markDirty();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      if (setting.ssl)
        SectionCard(
          title: '证书内容',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              certsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  '证书列表加载失败：${errorMessage(e)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                data: (certs) {
                  final usable = certs.where((c) => c.usable).toList();
                  if (usable.isEmpty) {
                    return Text(
                      '暂无可用的已签发证书，可直接粘贴证书内容或点击下方「签发证书」',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: '使用已有证书'),
                    items: [
                      for (final cert in usable)
                        DropdownMenuItem(
                          value: cert.id,
                          child: Text(
                            cert.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      CertItem? found;
                      for (final item in usable) {
                        if (item.id == id) {
                          found = item;
                          break;
                        }
                      }
                      final cert = found;
                      if (cert == null) return;
                      setState(() {
                        setting.sslCert = cert.cert;
                        setting.sslKey = cert.key;
                        _sslCertController.text = cert.cert;
                        _sslKeyController.text = cert.key;
                      });
                      _markDirty();
                      showSnack(context, '已填入证书内容，保存后生效');
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _sslCertController,
                minLines: 4,
                maxLines: 10,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: '证书（PEM）',
                  hintText: '-----BEGIN CERTIFICATE-----',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) {
                  setting.sslCert = v;
                  _markDirty();
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _sslKeyController,
                minLines: 4,
                maxLines: 10,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: '私钥（KEY）',
                  hintText: '-----BEGIN PRIVATE KEY-----',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) {
                  setting.sslKey = v;
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _certBusy ? null : _updateCertOnly,
                icon: _certBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined),
                label: Text(_certBusy ? '更新中…' : '仅更新证书文件'),
              ),
              const SizedBox(height: 8),
              Text(
                '「仅更新证书文件」调用 POST /website/cert，把上面的证书与私钥直接写入'
                '本网站的证书文件并重载 Web 服务器，不提交本页其他修改；'
                '若还改动了监听、域名等配置，请使用右下角的「保存配置」。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      SectionCard(
        title: '自动签发',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '使用面板默认 ACME 账户为当前域名签发证书并自动部署；'
              '泛域名需要先在证书管理中配置 DNS 账号。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _obtainBusy ? null : _obtainCert,
              icon: _obtainBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(_obtainBusy ? '正在签发…' : '签发证书'),
            ),
          ],
        ),
      ),
    ]);
  }

  // -------------------------------------------------------------- 伪静态

  Widget _buildRewriteTab() {
    final setting = _setting!;
    final theme = Theme.of(context);
    final rewritesAsync = ref.watch(websiteRewritesProvider);

    return _tabBody([
      SectionCard(
        title: '规则模板',
        child: rewritesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(
            '模板加载失败：${errorMessage(e)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
          data: (rewrites) {
            if (rewrites.isEmpty) {
              return Text(
                '面板未提供伪静态模板',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              );
            }
            final names = rewrites.keys.toList()..sort();
            return DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: '选择模板后填入下方内容'),
              items: [
                for (final name in names)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (name) {
                final content = rewrites[name];
                if (content == null) return;
                setState(() {
                  setting.rewrite = content;
                  _rewriteController.text = content;
                });
                _markDirty();
              },
            );
          },
        ),
      ),
      SectionCard(
        title: '伪静态规则',
        child: TextField(
          controller: _rewriteController,
          minLines: 10,
          maxLines: 24,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'location / { ... }',
            alignLabelWithHint: true,
          ),
          onChanged: (v) {
            setting.rewrite = v;
            _markDirty();
          },
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ 反向代理

  Widget _buildProxyTab() {
    final setting = _setting!;
    return _tabBody([
      SectionCard(
        title: '上游服务器',
        child: UpstreamListField(
          upstreams: setting.upstreams,
          onChanged: _markDirty,
        ),
      ),
      SectionCard(
        title: '代理规则',
        child: ProxyListField(
          proxies: setting.proxies,
          onChanged: _markDirty,
        ),
      ),
    ]);
  }

  // -------------------------------------------------------------- 重定向

  Widget _buildRedirectTab() {
    final setting = _setting!;
    return _tabBody([
      SectionCard(
        title: '重定向规则',
        child: RedirectListField(
          redirects: setting.redirects,
          onChanged: _markDirty,
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- 高级

  Widget _buildAdvancedTab() {
    final setting = _setting!;
    final theme = Theme.of(context);
    final isNginx =
        ref.watch(installedEnvironmentProvider).valueOrNull?.isNginx ?? true;
    // 面板默认日志路径（与前端一致，面板根目录固定为 /opt/ace）。
    final defaultAccessLog = '/opt/ace/sites/${setting.name}/log/access.log';
    final defaultErrorLog = '/opt/ace/sites/${setting.name}/log/error.log';

    return _tabBody([
      if (isNginx)
        SectionCard(
          title: '访问统计',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用访问统计'),
            subtitle: const Text('开启后可在统计页查看 PV/UV、URI、IP 等数据'),
            value: setting.statEnabled,
            onChanged: (v) {
              setState(() => setting.statEnabled = v);
              _markDirty();
            },
          ),
        ),
      SectionCard(
        title: '日志',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _accessLogController,
              decoration: const InputDecoration(
                labelText: '访问日志路径',
                helperText: '填 off 表示关闭访问日志',
              ),
              onChanged: (v) {
                setting.accessLog = v.trim();
                _markDirty();
              },
            ),
            _LogQuickActions(
              onDefault: () {
                setState(() {
                  setting.accessLog = defaultAccessLog;
                  _accessLogController.text = defaultAccessLog;
                });
                _markDirty();
              },
              onDisable: () {
                setState(() {
                  setting.accessLog = 'off';
                  _accessLogController.text = 'off';
                });
                _markDirty();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _errorLogController,
              decoration: const InputDecoration(
                labelText: '错误日志路径',
                helperText: '填 off 表示关闭错误日志',
              ),
              onChanged: (v) {
                setting.errorLog = v.trim();
                _markDirty();
              },
            ),
            _LogQuickActions(
              onDefault: () {
                setState(() {
                  setting.errorLog = defaultErrorLog;
                  _errorLogController.text = defaultErrorLog;
                });
                _markDirty();
              },
              onDisable: () {
                setState(() {
                  setting.errorLog = 'off';
                  _errorLogController.text = 'off';
                });
                _markDirty();
              },
            ),
          ],
        ),
      ),
      SectionCard(
        title: '限流限速',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用限流限速'),
              value: setting.rateLimit != null,
              onChanged: (v) {
                setState(() {
                  setting.rateLimit = v ? RateLimitConfig() : null;
                });
                _markDirty();
              },
            ),
            if (setting.rateLimit != null) ...[
              const SizedBox(height: 8),
              _NumberField(
                label: '站点最大并发数',
                helperText: '0 表示不限制',
                initialValue: setting.rateLimit!.perServer,
                onChanged: (v) {
                  setting.rateLimit!.perServer = v;
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              _NumberField(
                label: '单 IP 最大并发数',
                helperText: '0 表示不限制',
                initialValue: setting.rateLimit!.perIp,
                onChanged: (v) {
                  setting.rateLimit!.perIp = v;
                  _markDirty();
                },
              ),
              const SizedBox(height: 16),
              _NumberField(
                label: '单请求限速（KB/s）',
                helperText: '0 表示不限制',
                initialValue: setting.rateLimit!.rate,
                onChanged: (v) {
                  setting.rateLimit!.rate = v;
                  _markDirty();
                },
              ),
            ],
          ],
        ),
      ),
      SectionCard(
        title: '真实 IP',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '配置可信代理（CDN、Frp 等）来源后，日志与统计才能取到访客真实 IP。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用真实 IP'),
              value: setting.realIp != null,
              onChanged: (v) {
                setState(() {
                  setting.realIp = v ? RealIpConfig() : null;
                });
                _markDirty();
              },
            ),
            if (setting.realIp != null) ...[
              const SizedBox(height: 8),
              StringListField(
                label: '可信来源',
                initialValues: setting.realIp!.from,
                hintText: '127.0.0.1 或 10.0.0.0/8',
                addButtonText: '添加来源',
                onChanged: (values) {
                  setting.realIp!.from = values;
                  _markDirty();
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _realIpHeaders.contains(setting.realIp!.header)
                    ? setting.realIp!.header
                    : 'X-Forwarded-For',
                decoration: const InputDecoration(labelText: '真实 IP 请求头'),
                items: [
                  for (final header in _realIpHeaders)
                    DropdownMenuItem(value: header, child: Text(header)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => setting.realIp!.header = v);
                  _markDirty();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('递归查找'),
                subtitle: const Text('在 X-Forwarded-For 中递归查找真实 IP'),
                value: setting.realIp!.recursive,
                onChanged: (v) {
                  setState(() => setting.realIp!.recursive = v);
                  _markDirty();
                },
              ),
            ],
          ],
        ),
      ),
      SectionCard(
        title: '基本认证',
        child: KeyValueListField(
          label: '访问账号',
          initialValues: setting.basicAuth,
          keyHint: '用户名',
          valueHint: '密码',
          addButtonText: '添加账号',
          obscureValue: true,
          helperText: '配置后访问该网站需要输入用户名与密码',
          onChanged: (values) {
            setting.basicAuth = values;
            _markDirty();
          },
        ),
      ),
      SectionCard(
        title: '自定义配置',
        child: CustomConfigListField(
          configs: setting.customConfigs,
          onChanged: _markDirty,
        ),
      ),
    ]);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogQuickActions extends StatelessWidget {
  const _LogQuickActions({required this.onDefault, required this.onDisable});

  final VoidCallback onDefault;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        children: [
          TextButton(onPressed: onDefault, child: const Text('使用默认路径')),
          TextButton(onPressed: onDisable, child: const Text('关闭日志')),
        ],
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final String? helperText;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initialValue}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
      ),
      onChanged: (v) => widget.onChanged(int.tryParse(v.trim()) ?? 0),
    );
  }
}
