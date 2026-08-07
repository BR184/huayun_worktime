import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/storage_keys.dart';
import 'package:hikiot_worktime/screens/daily_hours_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('缺少员工编号时显示明确错误而非静默空工时', (tester) async {
    // 有 token 和团队，但没有 personNo（如登出后残留被清理的新账号）
    SharedPreferences.setMockInitialValues({
      StorageKeys.teamNo: 'team-1',
      StorageKeys.token: 'token-1',
      StorageKeys.onboardingCompleted: true,
    });

    await tester.pumpWidget(const MaterialApp(home: DailyHoursScreen()));
    await tester.pumpAndSettle();

    // 显示明确的错误提示与重新登录入口
    expect(find.textContaining('未找到员工编号'), findsOneWidget);
    expect(find.text('重新登录'), findsOneWidget);
    // 不静默显示空工时页面
    expect(find.text('今日打卡工时'), findsNothing);
  });
}
