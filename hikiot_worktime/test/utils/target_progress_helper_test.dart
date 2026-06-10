import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/target_progress_helper.dart';

void main() {
  group('TargetProgressHelper', () {
    test('expands daily targets when current percentage reaches 160', () {
      final result = TargetProgressHelper.buildDailyProgress(
        displayHours: 12.8,
        baseTarget: 120,
        smartSort: false,
        pinnedTarget: null,
      );

      expect(
        result.sortedTargetData.map((data) => data['target']),
        contains(300),
      );
    });

    test('smart sort puts highest achieved then next target first', () {
      final result = TargetProgressHelper.buildDailyProgress(
        displayHours: 9.2,
        baseTarget: 120,
        smartSort: true,
        pinnedTarget: null,
      );

      expect(result.highestAchievedTarget, 110);
      expect(result.nextToAchieveTarget, 120);
      expect(result.sortedTargetData.take(2).map((data) => data['target']), [
        110,
        120,
      ]);
    });

    test('pinned target is moved to the front after sorting', () {
      final result = TargetProgressHelper.buildDailyProgress(
        displayHours: 9.2,
        baseTarget: 120,
        smartSort: true,
        pinnedTarget: 150,
      );

      expect(result.sortedTargetData.first['target'], 150);
      expect(result.highestAchievedTarget, 110);
      expect(result.nextToAchieveTarget, 120);
    });

    test(
      'monthly progress keeps smart ordering and folded completed targets',
      () {
        final result = TargetProgressHelper.buildMonthlyProgress(
          adjustedTotalHours: 80,
          baseHours: 80,
          avgHoursPerDay: 9,
          remainingWorkDays: 5,
          baseTarget: 120,
          smartSort: true,
          pinnedTarget: null,
        );

        expect(result.highestAchievedTarget, 110);
        expect(result.nextToAchieveTarget, 120);
        expect(result.sortedTargetData.take(2).map((data) => data['target']), [
          110,
          120,
        ]);
        expect(result.sortedTargetData.last['target'], 100);
      },
    );

    test('monthly progress moves pinned target to front after smart sort', () {
      final result = TargetProgressHelper.buildMonthlyProgress(
        adjustedTotalHours: 80,
        baseHours: 80,
        avgHoursPerDay: 9,
        remainingWorkDays: 5,
        baseTarget: 120,
        smartSort: true,
        pinnedTarget: 150,
      );

      expect(result.sortedTargetData.first['target'], 150);
      expect(result.highestAchievedTarget, 110);
      expect(result.nextToAchieveTarget, 120);
    });
  });
}
