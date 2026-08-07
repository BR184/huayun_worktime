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

    test('truncates billable hours and percentages to one decimal', () {
      expect(WorkTimeCalculator.billableHours(8.59), 8.5);
      expect(
        WorkTimeCalculator.calculatePercentage(hours: 8.59, baseHours: 8),
        106.2,
      );
      expect(
        WorkTimeCalculator.calculatePercentage(hours: 79.99, baseHours: 80),
        99.8,
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
