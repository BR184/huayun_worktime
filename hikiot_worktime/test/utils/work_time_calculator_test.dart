import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/work_time_calculator.dart';

void main() {
  group('WorkTimeCalculator', () {
    setUp(() {
      WorkTimeCalculator.lunchStartMinutes = 12 * 60;
      WorkTimeCalculator.lunchEndMinutes = 13 * 60;
    });

    tearDown(() {
      WorkTimeCalculator.lunchStartMinutes = 12 * 60;
      WorkTimeCalculator.lunchEndMinutes = 13 * 60;
    });

    test('uses configured lunch duration for lunch deduction', () {
      WorkTimeCalculator.lunchStartMinutes = 12 * 60;
      WorkTimeCalculator.lunchEndMinutes = 12 * 60 + 45;

      expect(WorkTimeCalculator.getLunchDeductionMinutes(9 * 60, 18 * 60), 45);
    });

    test('does not add time when lunch end is before lunch start', () {
      WorkTimeCalculator.lunchStartMinutes = 13 * 60;
      WorkTimeCalculator.lunchEndMinutes = 12 * 60;

      expect(WorkTimeCalculator.lunchDurationMinutes, 0);
      expect(WorkTimeCalculator.getLunchDeductionMinutes(9 * 60, 18 * 60), 0);
      expect(WorkTimeCalculator.calculateWorkHoursStr('09:00', '18:00'), 9.0);
    });

    test('deducts lunch for work sessions that end after midnight', () {
      expect(WorkTimeCalculator.calculateWorkHoursStr('09:00', '00:30'), 14.5);
      expect(WorkTimeCalculator.calculateWorkHoursStr('12:30', '00:30'), 11.5);
      expect(WorkTimeCalculator.calculateWorkHoursStr('21:00', '00:30'), 3.5);
    });

    test('keeps integer values compact and truncates decimal values', () {
      expect(WorkTimeCalculator.formatHours(0), '0');
      expect(WorkTimeCalculator.formatHours(8), '8');
      expect(WorkTimeCalculator.formatHours(0.0), '0.00');
      expect(WorkTimeCalculator.formatHours(8.0), '8.00');
      expect(WorkTimeCalculator.formatHours(5.559), '5.55');
    });

    test('truncates billable hours to one decimal and percentages to two', () {
      expect(WorkTimeCalculator.billableHours(8.59), 8.5);
      // 百分比是计算输出，不受工时限一位影响，保留两位（截断）
      expect(
        WorkTimeCalculator.calculatePercentage(hours: 8.59, baseHours: 8),
        106.25,
      );
      expect(
        WorkTimeCalculator.calculatePercentage(hours: 79.99, baseHours: 80),
        99.87,
      );
      expect(
        WorkTimeCalculator.calculatePercentage(hours: 8, baseHours: 0),
        0.0,
      );
      expect(WorkTimeCalculator.formatBillableHours(8.59), '8.5');
    });

    test('monthly accumulation must truncate per-day before summing', () {
      // 月度累计口径：每天的工时先截断到一位小数再累加，
      // 百分位（如两天的 .04+.03）不得进入累计值
      final day1 = WorkTimeCalculator.billableHours(8.04);
      final day2 = WorkTimeCalculator.billableHours(8.03);
      expect(day1 + day2, 16.0);
      // 直接累加原始值会把百分位计入（与公司口径矛盾）
      expect(8.04 + 8.03, isNot(16.0));
    });

    test('next whole tenth time snaps to the next 6-minute boundary', () {
      // 8:00 打卡，14:00 下班 = 360 分钟 = 6.0h，已凑整
      final checkIn = DateTime(2026, 8, 7, 8, 0);
      expect(
        WorkTimeCalculator.nextWholeTenthTime(
          checkIn,
          DateTime(2026, 8, 7, 14, 0),
        ),
        DateTime(2026, 8, 7, 14, 0),
      );
      // 13:55 = 355 分钟，355 % 6 = 1 → 等 5 分钟到 14:00
      expect(
        WorkTimeCalculator.nextWholeTenthTime(
          checkIn,
          DateTime(2026, 8, 7, 13, 55),
        ),
        DateTime(2026, 8, 7, 14, 0),
      );
      // 14:03 = 363 分钟，363 % 6 = 3 → 等 3 分钟到 14:06
      expect(
        WorkTimeCalculator.nextWholeTenthTime(
          checkIn,
          DateTime(2026, 8, 7, 14, 3),
        ),
        DateTime(2026, 8, 7, 14, 6),
      );
      // 13:01 = 301 分钟，301 % 6 = 1 → 等 5 分钟到 13:06（5.1h）
      expect(
        WorkTimeCalculator.nextWholeTenthTime(
          checkIn,
          DateTime(2026, 8, 7, 13, 1),
        ),
        DateTime(2026, 8, 7, 13, 6),
      );
    });

    test('wasted fraction is the truncated hundredths remainder', () {
      // 无效工时 = 显示两位值 - 计入一位值（与 formatHours 显示链一致，
      // 浮点下界下 8.04 显示为 8.03，残差 0.03）
      expect(WorkTimeCalculator.wastedFraction(8.04), 0.03);
      expect(WorkTimeCalculator.wastedFraction(8.03), 0.02);
      expect(WorkTimeCalculator.wastedFraction(8.5333), 0.03);
      expect(WorkTimeCalculator.wastedFraction(8.0), 0.0);
      expect(WorkTimeCalculator.wastedFraction(0.09), 0.09);
      // 月度无效工时 = 逐日残差累计
      final wasted =
          WorkTimeCalculator.wastedFraction(8.04) +
          WorkTimeCalculator.wastedFraction(8.03);
      expect(wasted, 0.05);
    });

    test('formats raw punch duration including after-midnight checkout', () {
      expect(
        WorkTimeCalculator.formatPunchDuration('09:00', '18:30'),
        '9.50小时',
      );
      expect(
        WorkTimeCalculator.formatPunchDuration('09:00', '00:30'),
        '15.50小时',
      );
      expect(WorkTimeCalculator.formatPunchDuration('09:00', null), '--');
      expect(WorkTimeCalculator.formatPunchDuration('bad', '18:30'), '--');
    });
  });
}
