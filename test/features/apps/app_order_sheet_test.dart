import 'package:acepocket/core/api/api_client.dart';
import 'package:acepocket/core/api/api_exception.dart';
import 'package:acepocket/core/models/server.dart';
import 'package:acepocket/features/apps/models/app_item.dart';
import 'package:acepocket/features/apps/models/paged.dart';
import 'package:acepocket/features/apps/providers/apps_providers.dart';
import 'package:acepocket/features/apps/repo/apps_repo.dart';
import 'package:acepocket/features/apps/widgets/app_order_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 占位服务器：RFC 5737 文档地址 + 假令牌，不指向任何真实主机。
const _server = ServerConfig(
  id: 'test-server',
  name: '测试面板',
  baseUrl: 'https://192.0.2.1:8888',
  tokenId: '1',
  token: 'unit-test-token',
);

class _FakeAppsRepo extends AppsRepo {
  _FakeAppsRepo() : super(ApiClient(_server));

  @override
  Future<Paged<AppItem>> list({
    required int page,
    required int limit,
    String category = '',
    String query = '',
    bool installedOnly = false,
  }) async {
    return Paged<AppItem>(
      items: [
        AppItem.fromJson(const <String, dynamic>{
          'slug': 'nginx',
          'name': 'Nginx',
          'installed': true,
          'show': true,
        }),
        AppItem.fromJson(const <String, dynamic>{
          'slug': 'mysql',
          'name': 'MySQL',
          'installed': true,
          'show': true,
        }),
      ],
      total: 2,
    );
  }

  @override
  Future<void> updateOrder(List<String> slugs) async {
    throw const ApiException('权限不足，无法保存排序');
  }
}

void main() {
  testWidgets('排序保存失败时在弹层内部展示错误，而不是被遮挡的 SnackBar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appsRepoProvider.overrideWithValue(_FakeAppsRepo())],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppOrderSheet(context),
                child: const Text('打开排序'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开排序'));
    await tester.pumpAndSettle();
    expect(find.text('Nginx'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 错误必须画在弹层内部：弹层没有自己的 Scaffold，SnackBar 会显示在
    // 应用级 ScaffoldMessenger 上、被模态层完全遮挡。
    expect(find.textContaining('保存排序失败'), findsOneWidget);
    expect(find.textContaining('权限不足'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // 弹层保持打开，用户可以修正后重试。
    expect(find.text('保存'), findsOneWidget);
  });
}
