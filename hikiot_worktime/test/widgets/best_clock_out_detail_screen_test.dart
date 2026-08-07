import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/storage_keys.dart';
import 'package:hikiot_worktime/core/theme/app_theme.dart';
import 'package:hikiot_worktime/screens/best_clock_out_detail_screen.dart';
import 'package:hikiot_worktime/services/mock_time_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => MockTimeService.instance.clear());

  testWidgets('地铁方向③末班后推荐区显示真实原因而非误导文案', (tester) async {
    // 周一 20:00，方向③清源大街（末班 19:58）已收班
    MockTimeService.instance.setMock(DateTime(2026, 8, 10, 20, 0));
    MockTimeService.instance.setPunches(['07:51', '19:50']);
    SharedPreferences.setMockInitialValues({
      StorageKeys.commuteMode: 'metro',
      StorageKeys.commuteMetroDirection: 2,
      StorageKeys.commuteMetroWalkMinutes: 7,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BestClockOutDetailScreen(checkInMinutes: 7 * 60 + 51),
      ),
    );
    // 详情页每秒刷新，用 pump 而非 pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 推荐区显示真实原因
    expect(find.textContaining('该方向末班 19:58 已过'), findsWidgets);
    // 不再显示误导的"打卡后…"
    expect(find.textContaining('打卡后这里会给出'), findsNothing);
    // 时间轴标题显示方向与末班
    expect(find.textContaining('清源大街'), findsWidgets);
  });

  testWidgets('未打卡时推荐区提示打卡', (tester) async {
    MockTimeService.instance.clear();
    SharedPreferences.setMockInitialValues({StorageKeys.commuteMode: 'free'});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: BestClockOutDetailScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('打卡后这里会给出'), findsOneWidget);
  });
}
