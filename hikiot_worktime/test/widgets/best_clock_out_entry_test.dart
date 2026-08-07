import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
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
}
