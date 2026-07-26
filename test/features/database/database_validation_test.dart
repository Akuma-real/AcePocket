import 'package:flutter_test/flutter_test.dart';

import 'package:acepocket/features/database/utils/database_validation.dart';

void main() {
  group('validateDbUserHost', () {
    test('特殊值 % 与 localhost 通过', () {
      expect(validateDbUserHost('%'), isNull);
      expect(validateDbUserHost('localhost'), isNull);
    });

    test('IP、主机名与通配模式通过', () {
      expect(validateDbUserHost('192.0.2.10'), isNull);
      expect(validateDbUserHost('2001:db8::1'), isNull);
      expect(validateDbUserHost('db.example.com'), isNull);
      expect(validateDbUserHost('192.0.2.%'), isNull);
      expect(validateDbUserHost('%.example.com'), isNull);
    });

    test('IP/掩码 网段通过，非法掩码被拒绝', () {
      expect(validateDbUserHost('192.0.2.0/255.255.255.0'), isNull);
      expect(validateDbUserHost('192.0.2.0/24'), contains('掩码'));
      expect(validateDbUserHost('192.0.2.0/999.0.0.0'), contains('掩码'));
    });

    test('空输入与非法输入被拒绝', () {
      expect(validateDbUserHost(''), contains('主机'));
      expect(validateDbUserHost('   '), contains('主机'));
      expect(validateDbUserHost('a b'), contains('空格'));
      expect(validateDbUserHost('999.999.999.999'), isNotNull);
      expect(validateDbUserHost('http://example.com'), isNotNull);
      expect(validateDbUserHost('%!@#'), contains('通配符'));
    });
  });
}
