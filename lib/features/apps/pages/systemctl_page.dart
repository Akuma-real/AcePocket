import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../models/system_service.dart';
import '../providers/systemctl_providers.dart';
import '../widgets/add_service_dialog.dart';
import '../widgets/service_tile.dart';

/// 系统服务管理页面（/systemctl）。
///
/// 面板 `/api/systemctl/*` 只能按服务名逐个查询与操作，没有服务列表接口，
/// 因此列表由「已安装应用推导出的服务」+「用户手动添加的服务」组成。
class SystemctlPage extends ConsumerStatefulWidget {
  const SystemctlPage({super.key});

  @override
  ConsumerState<SystemctlPage> createState() => _SystemctlPageState();
}

class _SystemctlPageState extends ConsumerState<SystemctlPage> {
  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _refresh() async {
    // 重新推导服务列表，并让每个服务重新查询状态。
    for (final service in ref.read(serviceListProvider).valueOrNull ??
        const <ServiceRef>[]) {
      ref.invalidate(serviceStateProvider(service.name));
    }
    ref.invalidate(serviceListProvider);
    await ref.read(serviceListProvider.future);
  }

  Future<void> _addService() async {
    final existing = (ref.read(serviceListProvider).valueOrNull ??
            const <ServiceRef>[])
        .map((s) => s.name)
        .toList();
    final name = await showAddServiceDialog(context, existing: existing);
    if (name == null || name.isEmpty) return;
    await ref.read(customServicesProvider.notifier).add(name);
    if (!mounted) return;
    _toast('已添加 $name');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('系统服务'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addService,
        icon: const Icon(Icons.add),
        label: const Text('添加服务'),
      ),
      body: async.when(
        loading: () => const LoadingView(message: '加载服务列表…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(serviceListProvider),
        ),
        data: (services) {
          if (services.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyView(
                      message: '暂无可管理的服务\n'
                          '安装应用后会自动出现，也可手动添加服务名',
                      icon: Icons.settings_suggest_outlined,
                      action: FilledButton.icon(
                        onPressed: _addService,
                        icon: const Icon(Icons.add),
                        label: const Text('添加服务'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final appServices = services
              .where((s) => s.source == ServiceSource.app)
              .toList();
          final customServices = services
              .where((s) => s.source == ServiceSource.custom)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (appServices.isNotEmpty) ...[
                  const _GroupHeader(title: '应用服务'),
                  for (final service in appServices)
                    ServiceTile(key: ValueKey(service.name), service: service),
                ],
                if (customServices.isNotEmpty) ...[
                  const _GroupHeader(title: '自定义服务'),
                  for (final service in customServices)
                    ServiceTile(
                      key: ValueKey(service.name),
                      service: service,
                      onRemoved: () => ref.invalidate(serviceListProvider),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
