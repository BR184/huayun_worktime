import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
import 'package:hikiot_worktime/services/mock_time_service.dart';
import 'package:hikiot_worktime/utils/best_clockout_planner.dart';
import 'package:hikiot_worktime/widgets/best_clock_out_entry.dart';

void main() {
  Widget buildEntry(BestClockOutStatus status) {
    return MaterialApp(
      home: Scaffold(
        body: BestClockOutEntry(
          status: status,
          title: '现在是最佳下班时间',
          subtitle: '再等 4 分钟，工时正好 8.0h',
          onTap: () {},
        ),
      ),
    );
  }

  testWidgets('optimal state renders green with check icon', (tester) async {
    await tester.pumpWidget(buildEntry(BestClockOutStatus.optimal));

    expect(find.text('现在是最佳下班时间'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // 绿色语义：图标与主文案均为 success 色
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, AppColors.success);
    final title = tester.widget<Text>(find.text('现在是最佳下班时间'));
    expect(title.style?.color, AppColors.success);
  });

  testWidgets('approaching state renders amber with schedule icon', (
    tester,
  ) async {
    await tester.pumpWidget(buildEntry(BestClockOutStatus.approaching));

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.schedule));
    expect(icon.color, AppColors.warning);
  });

  testWidgets('unavailable state renders neutral grey with info icon', (
    tester,
  ) async {
    await tester.pumpWidget(buildEntry(BestClockOutStatus.unavailable));

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('poor state renders red with error icon', (tester) async {
    await tester.pumpWidget(buildEntry(BestClockOutStatus.poor));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, AppColors.error);
  });

  testWidgets('tapping the entry triggers onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BestClockOutEntry(
            status: BestClockOutStatus.approaching,
            title: '最佳下班 18:35',
            subtitle: '再等 4 分钟，工时正好 8.0h',
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('最佳下班 18:35'));
    expect(tapped, 1);
  });
  group('BestClockOutBanner 分栏', () {
    tearDown(() => MockTimeService.instance.clear());

    testWidgets('已打卡显示白底分栏：标题档位色 + 最近最佳下班时间', (tester) async {
      // 8:00 打卡，模拟 14:00（工时 6.0h 残差 0 → 绿）
      MockTimeService.instance.setMock(DateTime(2026, 8, 10, 14, 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BestClockOutBanner(
              checkInMinutes: 8 * 60,
              mode: CommuteMode.free,
              metroDirection: 0,
              metroWalkMinutes: 7,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // 绿色状态标题
      expect(find.text('现在下班正合适'), findsOneWidget);
      // 小字为"最近最佳下班时间 HH:MM"
      expect(find.textContaining('最近最佳下班时间'), findsOneWidget);
      // 白底 + 绿色描边
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect((decoration.border as Border).top.color, AppColors.success);
    });

    testWidgets('未打卡显示灰色提示', (tester) async {
      MockTimeService.instance.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BestClockOutBanner(
              checkInMinutes: null,
              mode: CommuteMode.free,
              metroDirection: 0,
              metroWalkMinutes: 7,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('最佳下班时间'), findsOneWidget);
      expect(find.textContaining('打卡后为你推荐'), findsOneWidget);
    });
  });
}
