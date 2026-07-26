import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/disk_models.dart';
import '../providers/toolbox_disk_providers.dart';
import 'disk_dialogs.dart';
import 'disk_widgets.dart';

/// 「磁盘」标签页：磁盘与分区列表，以及挂载 / 卸载 / 格式化 / 初始化操作。
class DiskTab extends ConsumerStatefulWidget {
  const DiskTab({super.key});

  @override
  ConsumerState<DiskTab> createState() => _DiskTabState();
}

class _DiskTabState extends ConsumerState<DiskTab> {
  /// 当前正在执行的操作标识（设备名 + 动作），用于禁用按钮并展示进度。
  String? _busy;

  bool get _locked => _busy != null;

  Future<void> _run(
    String key,
    Future<void> Function() action, {
    required String successMessage,
    bool refreshFstab = false,
  }) async {
    setState(() => _busy = key);
    try {
      await action();
      ref.invalidate(diskListProvider);
      ref.invalidate(lvmInfoProvider);
      if (refreshFstab) ref.invalidate(fstabProvider);
      if (!mounted) return;
      showSnack(context, successMessage);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ------------------------------------------------------------------ 操作

  Future<void> _mount(PartitionInfo part) async {
    final params = await showMountDialog(
      context,
      device: part.name,
      sizeText: formatBytes(part.size),
      fsType: part.fstype,
    );
    if (params == null || !mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '挂载 ${part.name}？',
      content: params.writeFstab
          ? '将 /dev/${part.name} 挂载到 ${params.path}，'
              '并写入 /etc/fstab 实现开机自动挂载。'
          : '将 /dev/${part.name} 挂载到 ${params.path}（重启后失效）。',
      confirmText: '挂载',
    );
    if (!confirmed) return;
    await _run(
      '${part.name}:mount',
      () => ref.read(toolboxDiskRepoProvider).mount(
            device: part.name,
            path: params.path,
            writeFstab: params.writeFstab,
            mountOption: params.mountOption,
          ),
      successMessage: '${part.name} 已挂载到 ${params.path}',
      refreshFstab: params.writeFstab,
    );
  }

  Future<void> _umount(String name, String mountPoint) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '卸载 $mountPoint？',
      content: '卸载后该挂载点下的数据将不可访问；'
          '若有程序正在使用该目录，卸载会失败。'
          '如已写入 fstab，重启后仍会自动挂载。',
      confirmText: '卸载',
      danger: true,
    );
    if (!confirmed) return;
    await _run(
      '$name:umount',
      () => ref.read(toolboxDiskRepoProvider).umount(mountPoint),
      successMessage: '$mountPoint 已卸载',
    );
  }

  Future<void> _format(PartitionInfo part) async {
    final fsType = await showFsTypeDialog(
      context,
      title: '格式化分区',
      target: '/dev/${part.name}　${formatBytes(part.size)}',
      warning: '格式化会清空该分区上的全部数据，且无法恢复。',
    );
    if (fsType == null || !mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '格式化 /dev/${part.name}？',
      content: '该分区将被重新格式化为 $fsType，'
          '分区上的所有文件会被永久删除，操作不可撤销。',
      confirmText: '继续',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final typed = await showTypedConfirmDialog(
      context,
      title: '最终确认',
      message: '即将格式化 /dev/${part.name} 为 $fsType，数据无法恢复。',
      requiredText: part.name,
      confirmText: '格式化',
    );
    if (!typed) return;
    await _run(
      '${part.name}:format',
      () => ref
          .read(toolboxDiskRepoProvider)
          .format(device: part.name, fsType: fsType),
      successMessage: '${part.name} 已格式化为 $fsType',
    );
  }

  Future<void> _init(DiskInfo disk) async {
    final fsType = await showFsTypeDialog(
      context,
      title: '初始化磁盘',
      target: '/dev/${disk.name}　${formatBytes(disk.size)}',
      warning: '初始化会卸载该磁盘的所有分区、清除分区表，'
          '重新创建一个占满整盘的分区并格式化，全部数据永久丢失。',
    );
    if (fsType == null || !mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '初始化 /dev/${disk.name}？',
      content: '磁盘上现有的 ${disk.partitions.length} 个分区会被全部删除，'
          '并新建单个 $fsType 分区。此操作不可撤销，'
          '请确认该磁盘上没有需要保留的数据。',
      confirmText: '继续',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final typed = await showTypedConfirmDialog(
      context,
      title: '最终确认',
      message: '即将清空 /dev/${disk.name} 并格式化为 $fsType，数据无法恢复。',
      requiredText: disk.name,
      confirmText: '初始化',
    );
    if (!typed) return;
    await _run(
      '${disk.name}:init',
      () => ref
          .read(toolboxDiskRepoProvider)
          .init(device: disk.name, fsType: fsType),
      successMessage: '${disk.name} 已初始化',
    );
  }

  Future<void> _showPartitions(DiskInfo disk) async {
    setState(() => _busy = '${disk.name}:detail');
    try {
      final devices =
          await ref.read(toolboxDiskRepoProvider).partitions(disk.name);
      if (!mounted) return;
      await showPartitionDetailDialog(
        context,
        device: disk.name,
        devices: devices,
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ------------------------------------------------------------------ 构建

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(diskListProvider);
    return async.when(
      loading: () => const LoadingView(message: '读取磁盘信息…'),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(diskListProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(diskListProvider);
          await ref.read(diskListProvider.future);
        },
        child: data.disks.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyView(
                    message: '未发现磁盘',
                    icon: Icons.storage_outlined,
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 6, bottom: 32),
                itemCount: data.disks.length,
                itemBuilder: (context, index) =>
                    _diskCard(data.disks[index], data),
              ),
      ),
    );
  }

  Widget _diskCard(DiskInfo disk, DiskListData data) {
    final theme = Theme.of(context);
    final usage = data.df[disk.mountpoint];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '/dev/${disk.name}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatBytes(disk.size)} · ${disk.modelLabel} · '
                      '${disk.partitions.length} 个分区',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (disk.isSystemDisk)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: TagChip(
                    label: '系统盘',
                    color: theme.colorScheme.error,
                  ),
                ),
              _isBusy('${disk.name}:detail') ||
                      _isBusy('${disk.name}:init')
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: BusyIndicator(),
                    )
                  : PopupMenuButton<String>(
                      tooltip: '磁盘操作',
                      enabled: !_locked,
                      onSelected: (value) {
                        switch (value) {
                          case 'detail':
                            _showPartitions(disk);
                          case 'init':
                            _init(disk);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'detail',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(Icons.info_outline),
                            title: Text('分区详情'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'init',
                          enabled: !disk.isSystemDisk,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              Icons.delete_forever_outlined,
                              color: disk.isSystemDisk
                                  ? theme.disabledColor
                                  : theme.colorScheme.error,
                            ),
                            title: Text(
                              disk.isSystemDisk ? '初始化磁盘（系统盘禁止）' : '初始化磁盘',
                              style: TextStyle(
                                color: disk.isSystemDisk
                                    ? theme.disabledColor
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
          const Divider(height: 20),
          if (disk.partitions.isEmpty)
            _wholeDiskRow(disk, usage)
          else
            for (final part in disk.partitions) _partitionRow(part),
        ],
      ),
    );
  }

  bool _isBusy(String key) => _busy == key;

  /// 无分区表的整盘（可能整盘挂载，也可能是待初始化的裸盘）。
  Widget _wholeDiskRow(DiskInfo disk, DfInfo? usage) {
    final theme = Theme.of(context);
    if (disk.mountpoint.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              disk.fstype.isEmpty
                  ? '该磁盘没有分区，可通过右上角「初始化磁盘」创建分区并格式化。'
                  : '该磁盘没有分区表，整盘文件系统为 ${disk.fstype}，当前未挂载。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '整盘挂载于 ${disk.mountpoint}'
                '${disk.fstype.isEmpty ? '' : '（${disk.fstype}）'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (_isBusy('${disk.name}:umount'))
              const BusyIndicator()
            else if (disk.mountpoint != '/')
              TextButton(
                onPressed:
                    _locked ? null : () => _umount(disk.name, disk.mountpoint),
                child: const Text('卸载'),
              ),
          ],
        ),
        if (usage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: UsageBar(percent: usage.percent)),
                const SizedBox(width: 10),
                Text(
                  '${formatBytes(usage.used)} / ${formatBytes(usage.size)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _partitionRow(PartitionInfo part) {
    final theme = Theme.of(context);
    final busy = _isBusy('${part.name}:mount') ||
        _isBusy('${part.name}:umount') ||
        _isBusy('${part.name}:format');

    return Padding(
      padding: EdgeInsets.only(left: part.depth * 14.0, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                part.type == 'lvm'
                    ? Icons.layers_outlined
                    : Icons.horizontal_split_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            part.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (part.type != 'part')
                          TagChip(
                            label: part.type,
                            color: theme.colorScheme.secondary,
                          ),
                        if (part.isRoot)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: TagChip(
                              label: '根分区',
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatBytes(part.size),
                        if (part.fstype.isNotEmpty) part.fstype,
                        part.mounted ? part.mountpoint : '未挂载',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: BusyIndicator(),
                )
              else
                PopupMenuButton<String>(
                  tooltip: '分区操作',
                  enabled: !_locked,
                  onSelected: (value) {
                    switch (value) {
                      case 'mount':
                        _mount(part);
                      case 'umount':
                        _umount(part.name, part.mountpoint);
                      case 'format':
                        _format(part);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!part.mounted)
                      const PopupMenuItem<String>(
                        value: 'mount',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.playlist_add_check_rounded),
                          title: Text('挂载'),
                        ),
                      ),
                    if (part.mounted)
                      PopupMenuItem<String>(
                        value: 'umount',
                        enabled: !part.isRoot,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.eject_outlined),
                          title: Text(part.isRoot ? '卸载（根分区禁止）' : '卸载'),
                        ),
                      ),
                    if (!part.mounted)
                      PopupMenuItem<String>(
                        value: 'format',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            '格式化',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (part.mounted)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Row(
                children: [
                  Expanded(child: UsageBar(percent: part.percent)),
                  const SizedBox(width: 10),
                  Text(
                    '${formatBytes(part.used)} / '
                    '${formatBytes(part.used + part.avail)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
