import 'package:acepocket/features/app_settings/models/app_settings.dart';
import 'package:acepocket/features/app_settings/providers/app_settings_providers.dart';
import 'package:acepocket/features/app_settings/repo/app_settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSettingsStore.instance.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('startupTabProvider', () {
    test('build 同步读取 Store 中的值', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppSettingsStore.startupTabKey: 'more',
      });
      await AppSettingsStore.instance.init();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(startupTabProvider), StartupTab.more);
    });

    test('setTab 更新 state 并持久化', () async {
      await AppSettingsStore.instance.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(startupTabProvider), StartupTab.home);

      await container
          .read(startupTabProvider.notifier)
          .setTab(StartupTab.websites);

      expect(container.read(startupTabProvider), StartupTab.websites);
      expect(AppSettingsStore.instance.startupTab, StartupTab.websites);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppSettingsStore.startupTabKey), 'websites');
    });
  });

  group('homePollIntervalProvider', () {
    test('build 同步读取 Store 中的值', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppSettingsStore.homePollIntervalKey: 30,
      });
      await AppSettingsStore.instance.init();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(homePollIntervalProvider), 30);
    });

    test('setInterval 更新 state 并持久化', () async {
      await AppSettingsStore.instance.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(homePollIntervalProvider),
        kDefaultHomePollIntervalSeconds,
      );

      await container.read(homePollIntervalProvider.notifier).setInterval(10);

      expect(container.read(homePollIntervalProvider), 10);
      expect(AppSettingsStore.instance.homePollIntervalSeconds, 10);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppSettingsStore.homePollIntervalKey), 10);
    });

    test('setInterval 传非法值时 sanitize 回退默认', () async {
      await AppSettingsStore.instance.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(homePollIntervalProvider.notifier).setInterval(7);

      expect(
        container.read(homePollIntervalProvider),
        kDefaultHomePollIntervalSeconds,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(AppSettingsStore.homePollIntervalKey),
        kDefaultHomePollIntervalSeconds,
      );
    });

    test('setInterval(0) 关闭轮询合法', () async {
      await AppSettingsStore.instance.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(homePollIntervalProvider.notifier).setInterval(0);

      expect(container.read(homePollIntervalProvider), kHomePollIntervalOff);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppSettingsStore.homePollIntervalKey), 0);
    });
  });

  group('autoCheckUpdateProvider', () {
    test('build 同步读取 Store 中的值', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppSettingsStore.autoCheckUpdateKey: false,
      });
      await AppSettingsStore.instance.init();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(autoCheckUpdateProvider), isFalse);
    });

    test('setEnabled 更新 state 并持久化', () async {
      await AppSettingsStore.instance.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(autoCheckUpdateProvider), isTrue);

      await container.read(autoCheckUpdateProvider.notifier).setEnabled(false);

      expect(container.read(autoCheckUpdateProvider), isFalse);
      expect(AppSettingsStore.instance.autoCheckUpdate, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppSettingsStore.autoCheckUpdateKey), isFalse);
    });
  });
}
