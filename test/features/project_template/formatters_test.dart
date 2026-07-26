import 'package:acepocket/features/project_template/widgets/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCpuPercent', () {
    test('整数不带小数点，小数保留一位', () {
      expect(formatCpuPercent(0), '0%');
      expect(formatCpuPercent(12), '12%');
      expect(formatCpuPercent(12.34), '12.3%');
    });

    test('不钳制到 100%：CPUQuota 200% 表示 2 个核心', () {
      expect(formatCpuPercent(200), '200%');
      expect(formatCpuPercent(150.5), '150.5%');
    });

    test('异常输入回退为 0%', () {
      expect(formatCpuPercent(double.nan), '0%');
      expect(formatCpuPercent(double.infinity), '0%');
      expect(formatCpuPercent(-5), '0%');
    });
  });

  group('trimDouble', () {
    test('去掉多余的 .0', () {
      expect(trimDouble(512), '512');
      expect(trimDouble(1.5), '1.5');
      expect(trimDouble(0), '0');
    });
  });
}
