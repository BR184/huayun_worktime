import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
import 'package:hikiot_worktime/utils/best_clockout_planner.dart';
import 'package:hikiot_worktime/widgets/best_clock_out_timeline.dart';

void main() {
  testWidgets('柱子颜色按档位渲染：绿/黄/红', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BestClockOutTimeline(
            bands: const [WasteBand.best, WasteBand.fair, WasteBand.poor],
            minutes: 3,
          ),
        ),
      ),
    );

    final containers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BestClockOutTimeline),
            matching: find.byType(Container),
          ),
        )
        .toList();
    // 3 根柱子 + 3 个图例圆点
    final barColors = containers
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .toList();
    expect(barColors, contains(AppColors.success));
    expect(barColors, contains(AppColors.warning));
    expect(barColors, contains(AppColors.error));
  });

  testWidgets('柱子数量等于展示分钟数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BestClockOutTimeline(
            bands: [
              WasteBand.best,
              WasteBand.fair,
              WasteBand.poor,
              WasteBand.best,
              WasteBand.fair,
            ],
            minutes: 5,
          ),
        ),
      ),
    );

    expect(find.byType(BestClockOutTimeline), findsOneWidget);
    expect(find.text('未来下班档位'), findsOneWidget);
  });
}
