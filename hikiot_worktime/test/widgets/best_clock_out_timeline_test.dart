import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
import 'package:hikiot_worktime/utils/best_clockout_planner.dart';
import 'package:hikiot_worktime/widgets/best_clock_out_timeline.dart';

void main() {
  Widget buildTimeline({
    List<WasteBand>? bands,
    int viewMinutes = 60,
    int? checkInMinutes,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BestClockOutTimeline(
          bands:
              bands ?? const [WasteBand.best, WasteBand.fair, WasteBand.poor],
          checkInMinutes: checkInMinutes,
          viewMinutes: viewMinutes,
        ),
      ),
    );
  }

  testWidgets('柱子颜色按档位渲染：绿/黄/红', (tester) async {
    await tester.pumpWidget(buildTimeline());

    final containers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BestClockOutTimeline),
            matching: find.byType(Container),
          ),
        )
        .toList();
    final barColors = containers
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .toList();
    expect(barColors, contains(AppColors.success));
    expect(barColors, contains(AppColors.warning));
    expect(barColors, contains(AppColors.error));
  });

  testWidgets('60 分钟视图标注现在/+30/+60 三个时间点', (tester) async {
    await tester.pumpWidget(buildTimeline(viewMinutes: 60));

    expect(find.textContaining('现在'), findsOneWidget);
    expect(find.textContaining('+30 分钟'), findsOneWidget);
    expect(find.textContaining('+60 分钟'), findsOneWidget);
  });

  testWidgets('连续绿色首柱显示最佳窗口标记', (tester) async {
    await tester.pumpWidget(
      buildTimeline(
        bands: const [
          WasteBand.fair,
          WasteBand.poor,
          WasteBand.best,
          WasteBand.best,
          WasteBand.fair,
        ],
      ),
    );

    expect(find.textContaining('最佳窗口'), findsOneWidget);
  });

  testWidgets('点击柱子后提示框显示时间与原因', (tester) async {
    await tester.pumpWidget(
      buildTimeline(
        bands: const [WasteBand.poor, WasteBand.fair, WasteBand.best],
        viewMinutes: 3,
        checkInMinutes: 8 * 60,
      ),
    );

    // 点击最左侧第一根柱子（柱子区：顶部提示框 44 + 间距 6 之后）
    final rect = tester.getRect(find.byType(BestClockOutTimeline));
    await tester.tapAt(Offset(rect.left + 10, rect.top + 80));
    await tester.pump();

    expect(find.textContaining('下班：'), findsOneWidget);
    expect(find.textContaining('别走'), findsOneWidget);
  });

  testWidgets('10 分钟视图显示倾斜时间标签', (tester) async {
    await tester.pumpWidget(buildTimeline(viewMinutes: 10));

    // 10 分钟视图的底部时间标签（HH:MM）
    expect(find.textContaining(':'), findsWidgets);
  });
}
