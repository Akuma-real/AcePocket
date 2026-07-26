import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/panel_setting.dart';
import '../providers/settings_providers.dart';
import '../widgets/memo_card.dart';
import '../widgets/setting_fields.dart';

/// 面板设置页（`GET/POST /api/setting`）。
///
/// 面板要求提交完整设置结构，因此本页在原始设置对象上 copyWith，
/// 未在移动端暴露的字段（如 hidden_menu、two_fa）原样回传，避免被清空。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingAsync = ref.watch(panelSettingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('面板设置'),
      ),
      body: settingAsync.when(
        loading: () => const LoadingView(message: '正在加载面板设置…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(panelSettingProvider),
        ),
        data: (setting) => _SettingForm(original: setting),
      ),
    );
  }
}

class _SettingForm extends ConsumerStatefulWidget {
  const _SettingForm({required this.original});

  final PanelSetting original;

  @override
  ConsumerState<_SettingForm> createState() => _SettingFormState();
}

class _SettingFormState extends ConsumerState<_SettingForm> {
  static const Map<String, String> _locales = {
    'zh_CN': '简体中文',
    'zh_TW': '繁體中文',
    'en': 'English',
  };
  static const Map<String, String> _channels = {
    'stable': '稳定版',
    'beta': '测试版',
  };
  static const Map<String, String> _backupFormats = {
    'tar.xz': 'tar.xz',
    'tar.gz': 'tar.gz',
    'tar.zst': 'tar.zst',
    'zip': 'zip',
    '7z': '7z',
  };
  static const Map<String, String> _entranceErrors = {
    '418': "418 I'm a teapot",
    'nginx': 'Nginx 404 页面',
    'close': '直接断开连接',
  };
  static const Map<String, String> _ipdbTypes = {
    '': '关闭',
    'subscribe': '在线订阅',
    'custom': '自定义文件',
  };
  static const Map<String, String> _tlsModes = {
    'off': '关闭（HTTP）',
    'acme': 'ACME 自动签发',
    'self-signed': '自签名证书',
    'custom': '自定义证书',
  };

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _port;
  late final TextEditingController _websitePath;
  late final TextEditingController _backupPath;
  late final TextEditingController _projectPath;
  late final TextEditingController _containerSock;
  late final TextEditingController _customLogo;
  late final TextEditingController _ipdbUrl;
  late final TextEditingController _ipdbPath;
  late final TextEditingController _entrance;
  late final TextEditingController _lifetime;
  late final TextEditingController _ipHeader;
  late final TextEditingController _cert;
  late final TextEditingController _key;

  late String _channel;
  late String _locale;
  late String _backupFormat;
  late String _ipdbType;
  late String _entranceError;
  late String _tls;
  late bool _loginCaptcha;
  late bool _offlineMode;
  late bool _autoUpdate;
  late List<String> _bindDomain;
  late List<String> _bindIp;
  late List<String> _bindUa;
  late List<String> _publicIp;

  bool _saving = false;
  bool _obtaining = false;

  @override
  void initState() {
    super.initState();
    final s = widget.original;
    _name = TextEditingController(text: s.name);
    _port = TextEditingController(text: '${s.port}');
    _websitePath = TextEditingController(text: s.websitePath);
    _backupPath = TextEditingController(text: s.backupPath);
    _projectPath = TextEditingController(text: s.projectPath);
    _containerSock = TextEditingController(text: s.containerSock);
    _customLogo = TextEditingController(text: s.customLogo);
    _ipdbUrl = TextEditingController(text: s.ipdbUrl);
    _ipdbPath = TextEditingController(text: s.ipdbPath);
    _entrance = TextEditingController(text: s.entrance);
    _lifetime = TextEditingController(text: '${s.lifetime}');
    _ipHeader = TextEditingController(text: s.ipHeader);
    _cert = TextEditingController(text: s.cert);
    _key = TextEditingController(text: s.key);

    _channel = _channels.containsKey(s.channel) ? s.channel : 'stable';
    _locale = _locales.containsKey(s.locale) ? s.locale : 'zh_CN';
    _backupFormat =
        _backupFormats.containsKey(s.backupFormat) ? s.backupFormat : 'tar.xz';
    _ipdbType = _ipdbTypes.containsKey(s.ipdbType) ? s.ipdbType : '';
    _entranceError =
        _entranceErrors.containsKey(s.entranceError) ? s.entranceError : '418';
    _tls = _tlsModes.containsKey(s.tls) ? s.tls : 'off';
    _loginCaptcha = s.loginCaptcha;
    _offlineMode = s.offlineMode;
    _autoUpdate = s.autoUpdate;
    _bindDomain = List<String>.from(s.bindDomain);
    _bindIp = List<String>.from(s.bindIp);
    _bindUa = List<String>.from(s.bindUa);
    _publicIp = List<String>.from(s.publicIp);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _port,
      _websitePath,
      _backupPath,
      _projectPath,
      _containerSock,
      _customLogo,
      _ipdbUrl,
      _ipdbPath,
      _entrance,
      _lifetime,
      _ipHeader,
      _cert,
      _key,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 依当前表单构造待提交的设置（在原始对象上覆盖，保留未暴露字段）。
  PanelSetting _buildSetting() {
    // 面板要求 entrance 非空，Web 端同样在为空时回落为 '/'。
    var entrance = _entrance.text.trim();
    if (entrance.isEmpty) entrance = '/';
    if (entrance != '/' && !entrance.startsWith('/')) entrance = '/$entrance';

    return widget.original.copyWith(
      name: _name.text.trim(),
      channel: _channel,
      locale: _locale,
      entrance: entrance,
      entranceError: _entranceError,
      loginCaptcha: _loginCaptcha,
      offlineMode: _offlineMode,
      autoUpdate: _autoUpdate,
      lifetime: int.tryParse(_lifetime.text.trim()) ?? widget.original.lifetime,
      ipHeader: _ipHeader.text.trim(),
      bindDomain: _bindDomain,
      bindIp: _bindIp,
      bindUa: _bindUa,
      websitePath: _websitePath.text.trim(),
      backupPath: _backupPath.text.trim(),
      backupFormat: _backupFormat,
      projectPath: _projectPath.text.trim(),
      containerSock: _containerSock.text.trim(),
      customLogo: _customLogo.text.trim(),
      ipdbType: _ipdbType,
      ipdbUrl: _ipdbUrl.text.trim(),
      ipdbPath: _ipdbPath.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? widget.original.port,
      tls: _tls,
      publicIp: _publicIp,
      cert: _cert.text,
      key: _key.text,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先修正表单中的错误')),
      );
      return;
    }

    final next = _buildSetting();
    final original = widget.original;
    // 端口 / 入口 / TLS 变化会改变面板访问地址，可能导致 App 连接中断。
    final risky = next.port != original.port ||
        next.entrance != original.entrance ||
        next.tls != original.tls;
    if (risky) {
      final ok = await showConfirmDialog(
        context,
        title: '确认保存',
        content: '本次修改包含面板访问地址相关设置'
            '${next.port != original.port ? '\n· 端口：${original.port} → ${next.port}' : ''}'
            '${next.entrance != original.entrance ? '\n· 入口：${original.entrance.isEmpty ? '(无)' : original.entrance} → ${next.entrance}' : ''}'
            '${next.tls != original.tls ? '\n· TLS：${_tlsModes[original.tls] ?? original.tls} → ${_tlsModes[next.tls] ?? next.tls}' : ''}'
            '\n\n保存后面板会重启，App 需要同步修改「服务器管理」中的地址与访问入口，否则将无法连接。',
        confirmText: '仍要保存',
        danger: true,
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final restart = await ref.read(settingRepoProvider).updateSetting(next);
      if (!mounted) return;
      if (restart) {
        final router = GoRouter.of(context);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('保存成功'),
            content: const Text(
              '面板正在重启以应用新配置，请稍候片刻再刷新。\n'
              '若修改了端口、入口或 TLS，请到「服务器管理」同步更新本机保存的服务器地址。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  router.push('/servers');
                },
                child: const Text('去修改服务器'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
      // 反馈展示完毕后再刷新，避免表单被重建导致提示丢失。
      ref.invalidate(panelSettingProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _obtainCert() async {
    final ok = await showConfirmDialog(
      context,
      title: _tls == 'acme' ? '刷新面板证书' : '重新生成自签证书',
      content: _tls == 'acme'
          ? '将向 ACME 服务商申请新的面板证书，需要公网 IP 已正确填写，过程可能耗时较久。'
          : '将重新生成面板自签名证书，签发完成后面板会重启。',
      confirmText: '开始签发',
    );
    if (!ok) return;

    setState(() => _obtaining = true);
    try {
      await ref.read(settingRepoProvider).obtainCert();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('证书签发成功，面板即将重启')),
      );
      ref.invalidate(panelSettingProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '签发失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _obtaining = false);
    }
  }

  String? _validatePort(String? value) {
    final v = int.tryParse((value ?? '').trim());
    if (v == null) return '请输入端口号';
    if (v < 1 || v > 65535) return '端口范围为 1 - 65535';
    return null;
  }

  String? _validateLifetime(String? value) {
    final v = int.tryParse((value ?? '').trim());
    if (v == null) return '请输入登录超时时间';
    if (v < 10 || v > 43200) return '范围为 10 - 43200 分钟';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = ref.watch(activeServerProvider);

    return Form(
      key: _formKey,
      child: RefreshIndicator(
        onRefresh: () async {
          final ok = await showConfirmDialog(
            context,
            title: '重新加载设置',
            content: '重新从面板拉取设置将丢弃当前未保存的修改，是否继续？',
            confirmText: '重新加载',
          );
          if (ok) ref.invalidate(panelSettingProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (server != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '当前服务器：${server.name}（${server.normalizedBaseUrl}）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // ------------------------------------------------------ 快捷入口
            SectionCard(
              title: '面板功能',
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('API 令牌'),
                    subtitle: const Text('创建、更新与删除面板 API 令牌'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/tokens'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('面板证书'),
                    subtitle: const Text('查看与更新面板 HTTPS 证书、私钥'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/cert'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.checklist_outlined),
                    title: const Text('任务中心'),
                    subtitle: const Text('查看后台任务与执行日志'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/tasks'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('面板日志'),
                    subtitle: const Text('操作 / 数据库 / HTTP / SSH 登录日志'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/logs'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('关于与外观'),
                    subtitle: const Text('版本信息、主题模式'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/about'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('服务器管理'),
                    subtitle: const Text('切换、编辑本机保存的面板服务器'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/servers'),
                  ),
                ],
              ),
            ),

            // -------------------------------------------------------- 基础设置
            SectionCard(
              title: '基础设置',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingTextField(
                    label: '面板名称',
                    controller: _name,
                    hint: 'AcePanel',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '面板名称不能为空' : null,
                  ),
                  SettingDropdown<String>(
                    label: '面板语言',
                    value: _locale,
                    items: _locales,
                    helper: '影响面板 Web 端与接口返回的语言',
                    onChanged: (v) => setState(() => _locale = v),
                  ),
                  SettingDropdown<String>(
                    label: '更新渠道',
                    value: _channel,
                    items: _channels,
                    onChanged: (v) => setState(() => _channel = v),
                  ),
                  SettingTextField(
                    label: '面板端口',
                    controller: _port,
                    hint: '8888',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validatePort,
                  ),
                  SettingTextField(
                    label: '默认网站目录',
                    controller: _websitePath,
                    hint: '/opt/ace/sites',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '网站目录不能为空' : null,
                  ),
                  SettingTextField(
                    label: '默认备份目录',
                    controller: _backupPath,
                    hint: '/opt/ace/backup',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '备份目录不能为空' : null,
                  ),
                  SettingDropdown<String>(
                    label: '备份压缩格式',
                    value: _backupFormat,
                    items: _backupFormats,
                    onChanged: (v) => setState(() => _backupFormat = v),
                  ),
                  SettingTextField(
                    label: '默认项目目录',
                    controller: _projectPath,
                    hint: '/opt/ace/projects',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? '项目目录不能为空' : null,
                  ),
                  SettingTextField(
                    label: '容器 Socket',
                    controller: _containerSock,
                    hint: '/var/run/docker.sock',
                  ),
                  SettingTextField(
                    label: '自定义 Logo',
                    controller: _customLogo,
                    hint: '请输入完整 URL',
                    helper: '留空使用面板默认 Logo',
                  ),
                  SettingSwitchTile(
                    title: '离线模式',
                    subtitle: '开启后不再访问外部网络（无法检查更新）',
                    value: _offlineMode,
                    onChanged: (v) => setState(() => _offlineMode = v),
                  ),
                  SettingSwitchTile(
                    title: '自动更新',
                    subtitle: '面板有新版本时自动升级',
                    value: _autoUpdate,
                    onChanged: (v) => setState(() => _autoUpdate = v),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------- IP 数据库
            SectionCard(
              title: 'IP 地理位置库',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingDropdown<String>(
                    label: '来源',
                    value: _ipdbType,
                    items: _ipdbTypes,
                    onChanged: (v) => setState(() => _ipdbType = v),
                  ),
                  if (_ipdbType == 'subscribe')
                    SettingTextField(
                      label: '订阅链接',
                      controller: _ipdbUrl,
                      hint: 'https://fastly.jsdelivr.net/npm/qqwry.ipdb/qqwry.ipdb',
                      helper: '每周自动更新，兼容 IPIP.NET 格式（.ipdb）',
                    ),
                  if (_ipdbType == 'custom')
                    SettingTextField(
                      label: '本地文件路径',
                      controller: _ipdbPath,
                      hint: '/opt/ace/panel/storage/geo.ipdb',
                    ),
                ],
              ),
            ),

            // -------------------------------------------------------- 安全设置
            SectionCard(
              title: '安全设置',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingTextField(
                    label: '登录超时（分钟）',
                    controller: _lifetime,
                    hint: '120',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateLifetime,
                  ),
                  SettingTextField(
                    label: '访问入口',
                    controller: _entrance,
                    hint: '/mypanel',
                    helper: '设置后须通过该路径访问面板；留空（或 /）表示不启用。'
                        '修改后请同步更新 App 中的服务器配置',
                  ),
                  SettingDropdown<String>(
                    label: '入口错误页',
                    value: _entranceError,
                    items: _entranceErrors,
                    helper: '使用错误入口访问时返回的伪装页面',
                    onChanged: (v) => setState(() => _entranceError = v),
                  ),
                  SettingSwitchTile(
                    title: '登录验证码',
                    subtitle: '连续 3 次登录失败后要求输入验证码',
                    value: _loginCaptcha,
                    onChanged: (v) => setState(() => _loginCaptcha = v),
                  ),
                  SettingTextField(
                    label: '真实 IP 请求头',
                    controller: _ipHeader,
                    hint: 'X-Real-IP',
                    helper: '使用 CDN 或反向代理时填写，留空则直接使用连接 IP',
                  ),
                  StringListField(
                    label: '绑定域名',
                    values: _bindDomain,
                    hint: 'panel.example.com',
                    helper: '限制只能通过指定域名访问面板，留空不限制',
                    onChanged: (v) => setState(() => _bindDomain = v),
                  ),
                  StringListField(
                    label: '绑定 IP',
                    values: _bindIp,
                    hint: '1.2.3.4 或 10.0.0.0/8',
                    helper: '限制可访问面板的来源 IP，支持 CIDR，留空不限制',
                    onChanged: (v) => setState(() => _bindIp = v),
                  ),
                  StringListField(
                    label: '绑定 UA',
                    values: _bindUa,
                    hint: 'Mozilla/5.0 ...',
                    helper: '限制可访问面板的 User-Agent，留空不限制。'
                        '注意：本 App 的 UA 与浏览器不同，谨慎使用',
                    onChanged: (v) => setState(() => _bindUa = v),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------ HTTPS 设置
            SectionCard(
              title: '面板 HTTPS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingDropdown<String>(
                    label: 'TLS 模式',
                    value: _tls,
                    items: _tlsModes,
                    helper: '修改后面板会重启，App 中的服务器地址需同步改为 http/https',
                    onChanged: (v) => setState(() => _tls = v),
                  ),
                  if (_tls == 'acme')
                    StringListField(
                      label: '公网 IP',
                      values: _publicIp,
                      hint: '203.0.113.10',
                      helper: 'ACME 签发面板证书所需，须为可从公网访问的地址',
                      onChanged: (v) => setState(() => _publicIp = v),
                    ),
                  if (_tls == 'custom') ...[
                    SettingTextField(
                      label: '证书（PEM）',
                      controller: _cert,
                      maxLines: 6,
                      hint: '-----BEGIN CERTIFICATE-----',
                    ),
                    SettingTextField(
                      label: '私钥（PEM）',
                      controller: _key,
                      maxLines: 6,
                      hint: '-----BEGIN PRIVATE KEY-----',
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push('/settings/cert'),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('只更新证书文件（不重启面板）'),
                    ),
                  ),
                  if (_tls == 'acme' || _tls == 'self-signed')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _obtaining ? null : _obtainCert,
                        icon: _obtaining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          _obtaining
                              ? '签发中…'
                              : (_tls == 'acme' ? '刷新证书' : '重新生成证书'),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const MemoCard(),

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
                label: Text(_saving ? '保存中…' : '保存面板设置'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '提示：保存会提交完整设置结构，App 未展示的字段（如隐藏菜单）将原样回传，不会被清空。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
