import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/panel_about.dart';
import '../providers/settings_providers.dart';
import '../widgets/setting_fields.dart';

/// App 版本（与 pubspec.yaml 的 version 保持一致）。
const String kAppVersion = '1.0.0';

/// AcePanel 开源仓库地址。
const String kProjectRepoUrl = 'https://github.com/acepanel/panel';

/// AcePanel 官网。
const String kProjectSiteUrl = 'https://acepanel.net';

/// API 文档地址。
const String kProjectApiDocUrl = 'https://acepanel.net/advanced/api';

/// 关于页：纯信息展示（App / 面板版本、开源地址）。
///
/// 外观等 App 偏好设置已移至「应用设置」（`/app-settings`）。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aboutAsync = ref.watch(aboutInfoProvider);
    final server = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(aboutInfoProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(aboutInfoProvider);
          try {
            await ref.read(aboutInfoProvider.future);
          } catch (_) {
            // 错误由下方 ErrorView 展示。
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _AppHeader(),

            // ---------------------------------------------------- 应用设置入口
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              onTap: () => context.push('/app-settings'),
              child: const ListTile(
                leading: Icon(Icons.app_settings_alt_outlined),
                title: Text('应用设置'),
                subtitle: Text('主题、启动行为、数据刷新、终端等 App 偏好'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),

            // -------------------------------------------------------- 面板信息
            aboutAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: LoadingView(message: '正在获取面板信息…'),
              ),
              error: (error, _) => SizedBox(
                height: 260,
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(aboutInfoProvider),
                ),
              ),
              data: (info) => _PanelInfoSection(info: info),
            ),

            // ------------------------------------------------------ 当前服务器
            if (server != null)
              SectionCard(
                title: '当前服务器',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InfoRow(label: '名称', value: server.name),
                    InfoRow(
                      label: '地址',
                      value: server.normalizedBaseUrl,
                      copyable: true,
                    ),
                    InfoRow(
                      label: '访问入口',
                      value: server.entrancePath.isEmpty
                          ? '未设置'
                          : server.entrancePath,
                    ),
                    InfoRow(label: '令牌 ID', value: server.tokenId),
                    InfoRow(
                      label: '面板账号',
                      value: server.hasCredentials
                          ? '${server.username}（已配置，可使用终端等实时功能）'
                          : '未配置（终端 / SSH 等 WebSocket 功能不可用）',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push('/servers/edit?id=${server.id}'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑服务器配置'),
                      ),
                    ),
                  ],
                ),
              ),

            // -------------------------------------------------------- 开源信息
            SectionCard(
              title: '开源信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _LinkRow(label: '项目仓库', url: kProjectRepoUrl),
                  _LinkRow(label: '官方网站', url: kProjectSiteUrl),
                  _LinkRow(label: 'API 文档', url: kProjectApiDocUrl),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'AcePanel 是全开源（BSD-3-Clause）、永久免费的 Linux 服务器运维面板，'
                '本 App 为其第三方移动客户端，通过面板 API 令牌（HMAC-SHA256 签名）访问。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.dns_outlined,
              size: 40,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text('AcePocket', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'App 版本 $kAppVersion',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelInfoSection extends StatelessWidget {
  const _PanelInfoSection({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final system = info.system;
    return Column(
      children: [
        SectionCard(
          title: '面板信息',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: '面板名称', value: info.panel.name),
              InfoRow(label: '面板版本', value: system.panelVersion, copyable: true),
              InfoRow(label: '构建版本', value: system.commitHash, copyable: true),
              InfoRow(label: '构建时间', value: system.buildTime),
              InfoRow(label: 'Go 版本', value: system.goVersion),
              InfoRow(label: '面板语言', value: info.panel.locale),
              if (info.userName.isNotEmpty)
                InfoRow(
                  label: '当前用户',
                  value: info.userEmail.isEmpty
                      ? info.userName
                      : '${info.userName}（${info.userEmail}）',
                ),
            ],
          ),
        ),
        SectionCard(
          title: '系统信息',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: '主机名', value: system.hostname),
              InfoRow(
                label: '操作系统',
                value: system.osName,
                valueColor: system.osSupported && !system.osEol
                    ? null
                    : theme.colorScheme.error,
              ),
              InfoRow(
                label: '内核',
                value: [system.kernelVersion, system.kernelArch]
                    .where((e) => e.isNotEmpty)
                    .join(' '),
              ),
              InfoRow(label: '运行时长', value: system.uptimeLabel),
              if (!system.osSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '当前系统版本不在面板官方支持范围内，部分功能可能异常。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (system.osEol)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '当前系统已停止维护（EOL），建议尽快升级。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 链接行：点击复制到剪贴板（App 未引入外部浏览器依赖）。
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制 $label 链接：$url')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                url,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(
              Icons.copy_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
