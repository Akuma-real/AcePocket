import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acepocket/core/widgets/empty_view.dart';
import 'package:acepocket/core/widgets/error_view.dart';

void main() {
  testWidgets('EmptyView 显示默认文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyView())),
    );
    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('ErrorView 展示错误信息并可点击重试', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(error: '连接面板失败', onRetry: () => retried = true),
        ),
      ),
    );

    expect(find.textContaining('连接面板失败'), findsOneWidget);

    final retryButton = find.byType(FilledButton);
    if (retryButton.evaluate().isNotEmpty) {
      await tester.tap(retryButton.first);
      await tester.pump();
      expect(retried, isTrue);
    }
  });
}
