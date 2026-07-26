import 'package:acepocket/features/files/widgets/transfer_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

/// [formatTransferBytes] 改为委托 core 的 `formatBytes` 后，
/// 传输场景特有的约定（总量未知传 -1）与原有观感必须保持不变——
/// 该函数同时被 cron_backup 的传输对话框复用。
void main() {
  group('formatTransferBytes', () {
    test('未知总量（-1）展示为「未知」而不是 0 B', () {
      expect(formatTransferBytes(-1), '未知');
      expect(formatTransferBytes(-1024), '未知');
    });

    test('字节档取整，KB 及以上保留两位小数', () {
      expect(formatTransferBytes(0), '0 B');
      expect(formatTransferBytes(512), '512 B');
      expect(formatTransferBytes(1024), '1.00 KB');
      expect(formatTransferBytes(5 * 1024 * 1024), '5.00 MB');
      expect(formatTransferBytes(1536 * 1024 * 1024), '1.50 GB');
    });

    test('超过 TB 继续进位而不是停在 1024.00 TB', () {
      expect(formatTransferBytes(1024 * 1024 * 1024 * 1024 * 1024), '1.00 PB');
    });
  });

  group('formatTransferSpeed', () {
    test('非正速度不展示', () {
      expect(formatTransferSpeed(0), '');
      expect(formatTransferSpeed(-1), '');
    });

    test('正速度带 /s 后缀', () {
      expect(formatTransferSpeed(1024), '1.00 KB/s');
    });
  });
}
