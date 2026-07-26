import 'package:acepocket/core/widgets/unsaved_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 推入一个被 [UnsavedChangesGuard] 包裹的页面，返回用于触发系统返回的 key。
Future<void> _pushGuardedPage(
  WidgetTester tester, {
  required bool dirty,
  VoidCallback? onDiscard,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UnsavedChangesGuard(
                  hasUnsavedChanges: dirty,
                  onDiscard: onDiscard,
                  child: const Scaffold(body: Text('编辑页')),
                ),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  expect(find.text('编辑页'), findsOneWidget);
}

void main() {
  testWidgets('无未保存修改时系统返回直接退出', (tester) async {
    await _pushGuardedPage(tester, dirty: false);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('编辑页'), findsNothing);
    expect(find.text('有未保存的修改，确定放弃吗？'), findsNothing);
  });

  testWidgets('有未保存修改时系统返回被拦截并弹确认框', (tester) async {
    await _pushGuardedPage(tester, dirty: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 页面仍在，确认框已弹出。
    expect(find.text('编辑页'), findsOneWidget);
    expect(find.text('有未保存的修改，确定放弃吗？'), findsOneWidget);

    // 选「继续编辑」→ 留在页面。
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑页'), findsOneWidget);
  });

  testWidgets('确认放弃后真正退出并回调 onDiscard', (tester) async {
    var discarded = false;
    await _pushGuardedPage(
      tester,
      dirty: true,
      onDiscard: () => discarded = true,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改').last);
    await tester.pumpAndSettle();

    expect(discarded, isTrue);
    expect(find.text('编辑页'), findsNothing);
  });
}
