import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/version/panel_feature.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/feature_gate.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/panel_setting.dart';
import '../providers/settings_providers.dart';
import '../widgets/setting_fields.dart';

/// 面板 HTTPS 证书页 `/settings/cert`。
///
/// - 当前证书与私钥从 `GET /api/setting` 读取（面板把 `panel/storage/cert.pem`
///   与 `cert.key` 的内容一并返回）；
/// - 保存调用 `POST /api/setting/cert`（`request.SettingCert`），面板会先解析
///   校验证书 / 私钥再落盘，HTTPS 监听通过 `tlscert.Reloader` 热加载，
///   无需重启面板；
/// - TLS 为 `acme` / `self-signed` 时可直接调用 `POST /api/setting/obtain_cert`
///   重新签发。
class PanelCertPage extends ConsumerWidget {
  const PanelCertPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingAsync = ref.watch(panelSettingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('面板证书'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(panelSettingProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const FeatureUnsupportedBanner(feature: PanelFeature.panelCert),
          Expanded(
            child: settingAsync.when(
              loading: () => const LoadingView(message: '正在读取面板证书…'),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(panelSettingProvider),
              ),
              data: (setting) => _CertForm(
                key: ValueKey(
                  '${setting.cert.hashCode}-${setting.key.hashCode}',
                ),
                setting: setting,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertForm extends ConsumerStatefulWidget {
  const _CertForm({super.key, required this.setting});

  final PanelSetting setting;

  @override
  ConsumerState<_CertForm> createState() => _CertFormState();
}

class _CertFormState extends ConsumerState<_CertForm> {
  static const Map<String, String> _tlsModes = {
    'off': '关闭（HTTP）',
    'acme': 'ACME 自动签发',
    'self-signed': '自签名证书',
    'custom': '自定义证书',
  };

  late final TextEditingController _cert =
      TextEditingController(text: widget.setting.cert);
  late final TextEditingController _key =
      TextEditingController(text: widget.setting.key);

  bool _saving = false;
  bool _obtaining = false;

  @override
  void dispose() {
    _cert.dispose();
    _key.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final cert = _cert.text.trim();
    final key = _key.text.trim();
    if (cert.isEmpty || key.isEmpty) {
      _snack('证书与私钥均不能为空');
      return;
    }
    if (!cert.contains('-----BEGIN')) {
      _snack('证书内容格式不正确，应为 PEM 文本');
      return;
    }
    if (!key.contains('-----BEGIN')) {
      _snack('私钥内容格式不正确，应为 PEM 文本');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '更新面板证书？',
      content: '新的证书与私钥会立即写入面板并热加载。'
          '${widget.setting.tls == 'off' ? '\n\n当前面板 TLS 模式为「关闭」，证书保存后不会生效，'
              '需要在面板设置中把 TLS 模式改为「自定义证书」。' : '\n\n若证书与当前访问的域名 / IP 不匹配，'
              'App 与浏览器都可能提示证书错误。'}',
      confirmText: '保存证书',
      danger: true,
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(settingRepoProvider).updateCert(cert: cert, key: key);
      if (!mounted) return;
      _snack('面板证书已更新');
      ref.invalidate(panelSettingProvider);
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _obtainCert() async {
    final isAcme = widget.setting.tls == 'acme';
    final ok = await showConfirmDialog(
      context,
      title: isAcme ? '重新签发面板证书' : '重新生成自签证书',
      content: isAcme
          ? '将向 ACME 服务商申请新的面板证书，需要面板设置中的公网 IP 正确且可从公网访问，'
              '过程可能耗时较久。'
          : '将重新生成面板自签名证书，签发完成后面板会重启。',
      confirmText: '开始签发',
    );
    if (!ok) return;

    setState(() => _obtaining = true);
    try {
      await ref.read(settingRepoProvider).obtainCert();
      if (!mounted) return;
      _snack('证书签发成功');
      ref.invalidate(panelSettingProvider);
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : '签发失败：$e');
    } finally {
      if (mounted) setState(() => _obtaining = false);
    }
  }

  Future<void> _pasteInto(
      TextEditingController controller, String label) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      _snack('剪贴板中没有文本内容');
      return;
    }
    controller.text = text.trim();
    _snack('已粘贴$label');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setting = widget.setting;
    final canObtain = setting.tls == 'acme' || setting.tls == 'self-signed';

    return RefreshIndicator(
      onRefresh: () async {
        final ok = await showConfirmDialog(
          context,
          title: '重新加载',
          content: '重新从面板读取证书将丢弃当前未保存的修改，是否继续？',
          confirmText: '重新加载',
        );
        if (ok) ref.invalidate(panelSettingProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionCard(
            title: '当前状态',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(
                  label: 'TLS 模式',
                  value: _tlsModes[setting.tls] ?? setting.tls,
                ),
                InfoRow(
                  label: '面板端口',
                  value: '${setting.port}',
                ),
                InfoRow(
                  label: '证书',
                  value: setting.cert.trim().isEmpty ? '未设置' : '已设置',
                  valueColor: setting.cert.trim().isEmpty
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                InfoRow(
                  label: '私钥',
                  value: setting.key.trim().isEmpty ? '未设置' : '已设置',
                  valueColor: setting.key.trim().isEmpty
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  '本页仅更新证书文件（POST /setting/cert），面板 HTTPS 监听会热加载新证书，'
                  '不会重启面板、也不会改动 TLS 模式等其他设置。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: '证书（PEM）',
            trailing: TextButton.icon(
              onPressed: () => _pasteInto(_cert, '证书'),
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('粘贴'),
            ),
            child: TextField(
              controller: _cert,
              minLines: 5,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              style:
                  theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '-----BEGIN CERTIFICATE-----',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SectionCard(
            title: '私钥（PEM）',
            trailing: TextButton.icon(
              onPressed: () => _pasteInto(_key, '私钥'),
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('粘贴'),
            ),
            child: TextField(
              controller: _key,
              minLines: 5,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              style:
                  theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '-----BEGIN PRIVATE KEY-----',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存证书'),
            ),
          ),
          if (canObtain)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _obtaining ? null : _obtainCert,
                icon: _obtaining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  _obtaining
                      ? '签发中…'
                      : (setting.tls == 'acme' ? '重新签发证书' : '重新生成自签证书'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '提示：证书更换后如果 App 无法连接，请检查「服务器管理」中的地址是否与证书域名一致；'
              '使用自签证书时需在服务器配置里开启「允许自签名证书」。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
