import 'package:flutter_test/flutter_test.dart';

import 'package:acepocket/features/toolbox_disk/utils/disk_validation.dart';

void main() {
  group('validateVolumeGroupName', () {
    test('常见卷组名通过', () {
      expect(validateVolumeGroupName('vg0'), isNull);
      expect(validateVolumeGroupName('data-vg'), isNull);
      expect(validateVolumeGroupName('vg_data.01'), isNull);
      expect(validateVolumeGroupName('vg+extra'), isNull);
      expect(validateVolumeGroupName('_internal'), isNull);
    });

    test('空名、点目录名与非法字符被拒绝', () {
      expect(validateVolumeGroupName(''), contains('卷组名称'));
      expect(validateVolumeGroupName('.'), contains('..'));
      expect(validateVolumeGroupName('..'), contains('..'));
      expect(validateVolumeGroupName('-vg'), isNotNull);
      expect(validateVolumeGroupName('vg 0'), isNotNull);
      expect(validateVolumeGroupName('vg/0'), isNotNull);
      expect(validateVolumeGroupName('卷组'), isNotNull);
      expect(validateVolumeGroupName('a' * 128), contains('过长'));
    });
  });

  group('validateMountOptions', () {
    test('留空与常见选项通过', () {
      expect(validateMountOptions(''), isNull);
      expect(validateMountOptions('   '), isNull);
      expect(validateMountOptions('defaults'), isNull);
      expect(validateMountOptions('defaults,noatime'), isNull);
      expect(validateMountOptions('rw,uid=1000,gid=1000'), isNull);
      expect(validateMountOptions('x-systemd.automount'), isNull);
    });

    test('空格、多余逗号与非法字符被拒绝', () {
      expect(validateMountOptions('defaults, noatime'), contains('空格'));
      expect(validateMountOptions('defaults,,noatime'), contains('逗号'));
      expect(validateMountOptions(',defaults'), contains('逗号'));
      expect(validateMountOptions('defaults,'), contains('逗号'));
      expect(validateMountOptions('no;atime'), contains('不支持的字符'));
    });
  });
}
