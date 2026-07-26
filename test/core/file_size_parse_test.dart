import 'package:acepocket/features/files/models/file_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFormattedSize', () {
    test('解析常见单位（1024 进制）', () {
      expect(parseFormattedSize('512 B'), 512);
      expect(parseFormattedSize('1 KB'), 1024);
      expect(parseFormattedSize('1.25 MB'), (1.25 * 1024 * 1024).round());
      expect(parseFormattedSize('2 GB'), 2 * 1024 * 1024 * 1024);
      expect(parseFormattedSize('0.00 B'), 0);
    });

    test('兼容无空格 / 小写 / KiB 形式', () {
      expect(parseFormattedSize('1.5MB'), (1.5 * 1024 * 1024).round());
      expect(parseFormattedSize('3 kb'), 3 * 1024);
      expect(parseFormattedSize('2 MiB'), 2 * 1024 * 1024);
    });

    test('不可识别的格式返回 null（调用方应放行）', () {
      expect(parseFormattedSize(''), isNull);
      expect(parseFormattedSize('-'), isNull);
      expect(parseFormattedSize('abc'), isNull);
    });

    test('编辑器阈值判断场景', () {
      // 1MB 警告阈值。
      expect(parseFormattedSize('1.01 MB')! > 1024 * 1024, isTrue);
      expect(parseFormattedSize('999 KB')! > 1024 * 1024, isFalse);
      // 10MB 面板上限。
      expect(parseFormattedSize('10.5 MB')! > 10 * 1024 * 1024, isTrue);
      expect(parseFormattedSize('9.9 MB')! > 10 * 1024 * 1024, isFalse);
    });
  });
}
