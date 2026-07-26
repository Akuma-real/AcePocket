import 'package:acepocket/features/toolbox_disk/models/disk_models.dart';
import 'package:acepocket/features/toolbox_disk/providers/toolbox_disk_providers.dart';
import 'package:acepocket/features/toolbox_disk/widgets/disk_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一块磁盘：[systemDisk] 为 true 时其分区带 `onSystemDisk` 标记。
DiskListData _data({required bool systemDisk}) {
  final part = PartitionInfo(
    name: systemDisk ? 'sda1' : 'sdb1',
    size: 512 * 1024 * 1024,
    type: 'part',
    // 未挂载才会出现「格式化」菜单项——EFI / BIOS boot 分区正是这种形态。
    mountpoint: '',
    fstype: 'vfat',
    uuid: '1234-ABCD',
    label: '',
    depth: 0,
    used: 0,
    avail: 0,
    percent: 0,
    onSystemDisk: systemDisk,
  );
  return DiskListData(
    disks: [
      DiskInfo(
        name: systemDisk ? 'sda' : 'sdb',
        size: 64 * 1024 * 1024 * 1024,
        type: 'disk',
        model: 'VIRTUAL-DISK',
        mountpoint: '',
        fstype: '',
        isSystemDisk: systemDisk,
        partitions: [part],
      ),
    ],
    df: const <String, DfInfo>{},
  );
}

Future<void> _pumpTab(WidgetTester tester, DiskListData data) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diskListProvider.overrideWith((ref) async => data)],
      child: const MaterialApp(home: Scaffold(body: DiskTab())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openFormatMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('分区操作'));
  await tester.pumpAndSettle();
}

void main() {
  group('系统盘上的分区格式化防护', () {
    testWidgets('系统盘分区的格式化入口有标注，并先弹系统盘警示', (tester) async {
      await _pumpTab(tester, _data(systemDisk: true));
      await _openFormatMenu(tester);

      expect(find.text('格式化（系统盘分区）'), findsOneWidget);
      expect(find.text('可能是引导分区，格式化后无法开机'), findsOneWidget);

      await tester.tap(find.text('格式化（系统盘分区）'));
      await tester.pumpAndSettle();

      // 第一步必须是系统盘警示，而不是直接进选文件系统。
      expect(find.text('这是系统盘上的分区'), findsOneWidget);
      expect(find.textContaining('/dev/sda1 位于系统盘 /dev/sda'), findsOneWidget);
      expect(find.text('格式化系统盘上的分区'), findsNothing);

      // 「返回」应当中止整条流程。
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      expect(find.text('这是系统盘上的分区'), findsNothing);
      expect(find.text('格式化系统盘上的分区'), findsNothing);
    });

    testWidgets('确认知晓风险后才进入选择文件系统这一步', (tester) async {
      await _pumpTab(tester, _data(systemDisk: true));
      await _openFormatMenu(tester);
      await tester.tap(find.text('格式化（系统盘分区）'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('我了解风险，继续'));
      await tester.pumpAndSettle();

      expect(find.text('格式化系统盘上的分区'), findsOneWidget);
      expect(find.textContaining('若它参与系统启动，服务器将无法开机'), findsOneWidget);
    });

    testWidgets('非系统盘分区不受影响，仍是原来的三步确认', (tester) async {
      await _pumpTab(tester, _data(systemDisk: false));
      await _openFormatMenu(tester);

      expect(find.text('格式化'), findsOneWidget);
      expect(find.text('格式化（系统盘分区）'), findsNothing);

      await tester.tap(find.text('格式化'));
      await tester.pumpAndSettle();

      // 直接进入选择文件系统，没有多余的系统盘警示。
      expect(find.text('这是系统盘上的分区'), findsNothing);
      expect(find.text('格式化分区'), findsOneWidget);
    });
  });
}
