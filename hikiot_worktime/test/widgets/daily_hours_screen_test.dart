import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/storage_keys.dart';
import 'package:hikiot_worktime/screens/daily_hours_screen.dart';
import 'package:hikiot_worktime/services/mock_time_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => MockTimeService.instance.clear());

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

  testWidgets('模拟到工作日周一后每日页显示工作日而非休息日', (tester) async {
    // 真实今天是周六（若测试日不是周六，用日期+7 天保证不等）
    final today = DateTime.now();
    // 找到一个必然为工作日的模拟日期（向后偏移直到 weekday<=5）
    var mockDate = today.add(const Duration(days: 1));
    while (mockDate.weekday > 5) {
      mockDate = mockDate.add(const Duration(days: 1));
    }
    MockTimeService.instance.setMock(
      DateTime(mockDate.year, mockDate.month, mockDate.day, 10, 0),
    );
    MockTimeService.instance.setPunches(['08:05', '10:00']);

    SharedPreferences.setMockInitialValues({
      StorageKeys.teamNo: 'team-1',
      StorageKeys.token: 'token-1',
      StorageKeys.personNo: 'person-1',
      StorageKeys.onboardingCompleted: true,
    });

    await tester.pumpWidget(const MaterialApp(home: DailyHoursScreen()));
    await tester.pumpAndSettle();

    // 模拟工作日：不显示"休息日"类型，显示"工作日"
    expect(find.text('休息日'), findsNothing);
    expect(find.text('工作日'), findsWidgets);
  });
}
