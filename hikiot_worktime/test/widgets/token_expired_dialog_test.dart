import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/token_expired_service.dart';

void main() {
  Widget buildHost() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () {}, child: const Text('占位按钮')),
          ),
        ),
      ),
    );
  }

  testWidgets('token expired triggered repeatedly shows only one dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());
    final context = tester.element(find.byType(Scaffold));

    // 模拟多个页面同时触发 token 失效（如每日页+月度页并发刷新）
    final first = TokenExpiredService.handleTokenExpired(context);
    final second = TokenExpiredService.handleTokenExpired(context);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 只弹出一个失效对话框，不会重复弹框
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('登录状态已失效'), findsOneWidget);

    // 点击"稍后再说"关闭，不触发登出导航
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    await first;
    await second;
  });

  testWidgets('dialog guard resets after closing so next trigger works', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());
    final context = tester.element(find.byType(Scaffold));

    // 注意：handleTokenExpired 会等待用户操作对话框，不能直接 await
    //（会阻塞测试体导致无法 pump），必须持有 future、交互后再 await。
    // 第一次触发并关闭
    final first = TokenExpiredService.handleTokenExpired(context);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    await first;

    // 第二次触发仍然能正常弹框
    final second = TokenExpiredService.handleTokenExpired(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    await second;
  });
}
