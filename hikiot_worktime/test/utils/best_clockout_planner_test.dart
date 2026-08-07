import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/data/metro_schedule.dart';
import 'package:hikiot_worktime/utils/best_clockout_planner.dart';

void main() {
  group('WasteBand 分档', () {
    test('0.00~0.02 最佳，0.03~0.05 一般，0.06~0.09 较差', () {
      expect(BestClockOutPlanner.bandOf(0.0), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.01), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.02), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.03), WasteBand.fair);
      expect(BestClockOutPlanner.bandOf(0.05), WasteBand.fair);
      expect(BestClockOutPlanner.bandOf(0.06), WasteBand.poor);
      expect(BestClockOutPlanner.bandOf(0.09), WasteBand.poor);
    });

    test('浪费分钟 = 残差 × 60', () {
      expect(BestClockOutPlanner.wasteMinutesOf(0.02), 1.2);
      expect(BestClockOutPlanner.wasteMinutesOf(0.05), 3.0);
      expect(BestClockOutPlanner.wasteMinutesOf(0.09), 5.4);
    });
  });

  group('自由模式', () {
    test('下一个最佳时刻是最近的整十分位（6 分钟边界）', () {
      // 8:00 打卡，14:03 → 已 363 分钟，363%6=3 → 等 3 分钟到 14:06
      expect(
        BestClockOutPlanner.nextBestFreeTime(8 * 60, 14 * 60 + 3),
        14 * 60 + 6,
      );
      // 恰好在整点
      expect(BestClockOutPlanner.nextBestFreeTime(8 * 60, 14 * 60), 14 * 60);
    });
  });

  group('地铁模式', () {
    test('候选班次下班时刻 = 到站 - 步行分钟，取性价比最高', () {
      // 8:00 打卡，17:00 现在，默认步行 7 分钟。17:06 班次 → 下班 16:59（已过）；
      // 17:11 班次 → 下班 17:04（wait 4，工时 544 分钟残差 0.06 较差 3.6 分钟，
      // score 7.6）；17:15 → 17:08（wait 8，残差 0.03 一般 1.8，score 9.8）
      final plan = BestClockOutPlanner.bestMetroPlan(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        nowMinutes: 17 * 60,
      );
      expect(plan, isNotNull);
      expect(plan!.trainTime, 17 * 60 + 11);
      expect(plan.departTime, 17 * 60 + 4);
      expect(plan.waitMinutes, 4);
    });

    test('步行分钟可配置：6 分钟时可赶上更早班次', () {
      // 步行 6 分钟：17:06 班次 → 下班 17:00（现在）残差 0 最佳
      final plan = BestClockOutPlanner.bestMetroPlan(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        nowMinutes: 17 * 60,
        walkMinutes: 6,
      );
      expect(plan, isNotNull);
      expect(plan!.trainTime, 17 * 60 + 6);
      expect(plan.departTime, 17 * 60);
      expect(plan.band, WasteBand.best);
      expect(plan.waitMinutes, 0);
    });

    test('错过 17:00 后推荐下一个高性价比班次', () {
      final plan = BestClockOutPlanner.bestMetroPlan(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        nowMinutes: 17 * 60 + 1,
      );
      expect(plan, isNotNull);
      expect(plan!.departTime, greaterThan(17 * 60 + 1));
    });

    test('当前能否赶上最近班次（按步行分钟推算）', () {
      final catchPlan = BestClockOutPlanner.currentMetroCatch(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        nowMinutes: 17 * 60,
      );
      expect(catchPlan, isNotNull);
      // 17:00 + 7 分钟 = 17:07 之后最近班次 17:11
      expect(catchPlan!.trainTime, 17 * 60 + 11);
    });

    test('末班后无候选', () {
      final plan = BestClockOutPlanner.bestMetroPlan(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        nowMinutes: 23 * 60,
      );
      expect(plan, isNull);
    });
  });
}
