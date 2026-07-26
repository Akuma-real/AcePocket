import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_card.dart';
import '../../app_update/providers/app_update_providers.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../../settings/providers/appearance_providers.dart';
import '../../terminal/models/terminal_settings.dart';
import '../../terminal/providers/terminal_providers.dart';
import '../models/app_settings.dart';
import '../providers/app_settings_providers.dart';
import '../widgets/pinned_cert_section.dart';

/// 应用设置页：App 本地偏好（外观 / 启动行为 / 数据刷新 / 终端 / 网络与安全 /
/// 关于与更新）。
///
/// 所有设置仅保存在本机，不会同步到面板服务器。
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: const [
          _AppearanceSection(),
          _StartupSection(),
          _DataRefreshSection(),
          _TerminalSection(),
          // 自带「网络与安全」SectionCard 外壳，直接放置即可。
          PinnedCertSection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

/// 分区底部的说明文字（bodySmall + onSurfaceVariant）。
class _SectionNote extends StatelessWidget {
  const _SectionNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 「外观」分区：主题模式三选一（跟随系统 / 亮色 / 暗色）。
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return SectionCard(
      title: '外观',
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      // Flutter 3.32+ 用 RadioGroup 管理分组值与变更回调。
      child: RadioGroup<ThemeMode>(
        groupValue: themeMode,
        onChanged: (v) {
          if (v == null) return;
          ref.read(appThemeModeProvider.notifier).setMode(v);
        },
        child: Column(
          children: ThemeMode.values
              .map(
                (mode) => RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(themeModeLabel(mode)),
                  subtitle: mode == ThemeMode.system
                      ? const Text('随系统深色模式自动切换')
                      : null,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// 「启动行为」分区：启动时默认打开的 tab。
class _StartupSection extends ConsumerWidget {
  const _StartupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupTab = ref.watch(startupTabProvider);

    return SectionCard(
      title: '启动行为',
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<StartupTab>(
            groupValue: startupTab,
            onChanged: (v) {
              if (v == null) return;
              ref.read(startupTabProvider.notifier).setTab(v);
            },
            child: Column(
              children: StartupTab.values
                  .map(
                    (tab) => RadioListTile<StartupTab>(
                      value: tab,
                      title: Text(tab.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          const _SectionNote('启动时默认打开的页面，更改后于下次启动 App 时生效。'),
        ],
      ),
    );
  }
}

/// 「数据刷新」分区：首页实时数据的轮询间隔。
class _DataRefreshSection extends ConsumerWidget {
  const _DataRefreshSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(homePollIntervalProvider);

    return SectionCard(
      title: '数据刷新',
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<int>(
            groupValue: interval,
            onChanged: (v) {
              if (v == null) return;
              ref.read(homePollIntervalProvider.notifier).setInterval(v);
            },
            child: Column(
              children: kHomePollIntervalOptions
                  .map(
                    (seconds) => RadioListTile<int>(
                      value: seconds,
                      title: Text(homePollIntervalLabel(seconds)),
                      subtitle: seconds == 0
                          ? const Text('关闭后首页仅在进入页面和下拉刷新时获取一次数据')
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
          const _SectionNote('首页实时数据（CPU / 内存 / 网络等）的轮询间隔。间隔越短数据越实时，但更耗电、更费流量。'),
        ],
      ),
    );
  }
}

/// 「终端」分区：与终端页内的快捷设置读写同一份状态。
class _TerminalSection extends ConsumerWidget {
  const _TerminalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(terminalSettingsProvider);
    final notifier = ref.read(terminalSettingsProvider.notifier);

    return SectionCard(
      title: '终端',
      trailing: TextButton(
        onPressed: notifier.reset,
        child: const Text('恢复默认'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------------------ 字号
          Row(
            children: [
              Text('字体大小', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                settings.fontSize.toStringAsFixed(0),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: '减小字号',
                onPressed: settings.fontSize > TerminalSettings.minFontSize
                    ? notifier.decreaseFontSize
                    : null,
                icon: const Icon(Icons.text_decrease),
              ),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: TerminalSettings.minFontSize,
                  max: TerminalSettings.maxFontSize,
                  divisions:
                      (TerminalSettings.maxFontSize - TerminalSettings.minFontSize)
                          .round(),
                  label: settings.fontSize.toStringAsFixed(0),
                  onChanged: notifier.setFontSize,
                ),
              ),
              IconButton(
                tooltip: '增大字号',
                onPressed: settings.fontSize < TerminalSettings.maxFontSize
                    ? notifier.increaseFontSize
                    : null,
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              r'root@acepanel:~# echo 预览 12345',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: settings.fontSize,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ------------------------------------------------------------ 开关
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.showKeyboardBar,
            onChanged: notifier.setShowKeyboardBar,
            title: const Text('显示快捷键条'),
            subtitle: const Text('Esc / Tab / 方向键 / Ctrl 组合键'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.autoReconnect,
            onChanged: notifier.setAutoReconnect,
            title: const Text('断线后自动重连一次'),
            subtitle: const Text('仅对已成功连接过的会话生效'),
          ),

          // -------------------------------------------------------- 回滚行数
          const SizedBox(height: 8),
          Row(
            children: [
              Text('回滚行数', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${settings.scrollback}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.scrollback.toDouble(),
            min: TerminalSettings.minScrollback.toDouble(),
            max: TerminalSettings.maxScrollback.toDouble(),
            divisions: 39,
            label: '${settings.scrollback}',
            onChanged: (value) => notifier.setScrollback(value.round()),
          ),
          Text(
            '回滚行数在下次打开终端时生效。'
            '以上设置与终端页内的快捷设置读写同一份状态，两处修改互相同步。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「关于与更新」分区：当前版本、自动检查更新开关与手动检查入口。
class _AboutSection extends ConsumerStatefulWidget {
  const _AboutSection();

  @override
  ConsumerState<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<_AboutSection> {
  /// 手动检查是否进行中（防重入：检查中禁点并显示进度指示）。
  bool _checking = false;

  /// 手动触发一次更新检查（无视被跳过的版本，有新版本直接弹窗）。
  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // AppUpdateChecker.check() 约定绝不抛异常，失败以 status 表达。
      final result = await ref.read(appUpdateCheckerProvider).check();
      if (!mounted) return;
      switch (result.status) {
        case UpdateCheckStatus.updateAvailable:
          await showAppUpdateDialog(context, result.release!);
        case UpdateCheckStatus.upToDate:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已是最新版本')),
          );
        case UpdateCheckStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('检查更新失败，请检查网络后重试')),
          );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(currentAppVersionProvider);
    final autoCheck = ref.watch(autoCheckUpdateProvider);

    return SectionCard(
      title: '关于与更新',
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('当前版本'),
            trailing: Text(
              version.when(
                data: (v) => 'v$v',
                loading: () => '…',
                error: (_, __) => '未知',
              ),
            ),
          ),
          SwitchListTile(
            value: autoCheck,
            onChanged: (v) {
              ref.read(autoCheckUpdateProvider.notifier).setEnabled(v);
            },
            title: const Text('启动时自动检查更新'),
            subtitle: const Text('启动后在后台静默检查，发现新版本时提示'),
          ),
          ListTile(
            title: const Text('检查更新'),
            enabled: !_checking,
            onTap: _checking ? null : _checkForUpdate,
            trailing: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
          ),
          const _SectionNote(
            '更新检查通过 GitHub Releases 进行，仅在你主动或开启自动检查时发起，不会上传任何数据。',
          ),
        ],
      ),
    );
  }
}
