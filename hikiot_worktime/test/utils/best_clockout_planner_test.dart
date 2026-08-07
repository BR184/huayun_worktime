import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/data/metro_schedule.dart';
import 'package:hikiot_worktime/utils/best_clockout_planner.dart';

void main() {
  group('WasteBand 分档', () {
    test('全模式统一按浪费分钟分档：<2 绿 / 2~4 黄 / >4 红', () {
      // 残差 0.02=1.2 分钟 → 绿；0.03=1.8 → 绿；0.05=3 → 黄；0.06=3.6 → 黄
      expect(BestClockOutPlanner.bandOf(0.0), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.01), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.02), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.03), WasteBand.best);
      expect(BestClockOutPlanner.bandOf(0.05), WasteBand.fair);
      expect(BestClockOutPlanner.bandOf(0.06), WasteBand.fair);
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
    test('总浪费分档统一阈值：<2 绿 / 2~4 黄 / >4 红', () {
      expect(BestClockOutPlanner.bandOfTotalWaste(0), WasteBand.best);
      expect(BestClockOutPlanner.bandOfTotalWaste(1.9), WasteBand.best);
      expect(BestClockOutPlanner.bandOfTotalWaste(2.0), WasteBand.fair);
      expect(BestClockOutPlanner.bandOfTotalWaste(4.0), WasteBand.fair);
      expect(BestClockOutPlanner.bandOfTotalWaste(4.1), WasteBand.poor);
    });

    test('metroWasteDetail：残差 + 等车 = 总浪费，按总和分档', () {
      // 8:00 打卡，16:58 下班，步行 7 分钟 → 17:05 到站，最近班次 17:06 → 等 1
      // 工时 538 分钟残差 0.06 → 3.6 → 总浪费 4.6 分钟 → 红（>4）
      final red = BestClockOutPlanner.metroWasteDetail(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        departTime: 16 * 60 + 58,
      );
      expect(red.clockWaste, 3.6);
      expect(red.waitMinutes, 1);
      expect(red.totalWaste, 4.6);
      expect(red.band, WasteBand.poor);
      expect(red.hasTrain, isTrue);

      // 17:12 下班 → 17:19 到站 → 17:20 班次（等 1）；工时 552 分钟残差 0
      // → 总浪费 1 <2 → 绿
      final green = BestClockOutPlanner.metroWasteDetail(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        departTime: 17 * 60 + 12,
      );
      expect(green.clockWaste, 0);
      expect(green.waitMinutes, 1);
      expect(green.totalWaste, 1);
      expect(green.band, WasteBand.best);

      // 17:06 下班 → 17:13 到站 → 17:15 班次（等 2）；残差 0
      // → 总浪费 2 → 黄（2 ≤ 4）
      final fair = BestClockOutPlanner.metroWasteDetail(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        departTime: 17 * 60 + 6,
      );
      expect(fair.waitMinutes, 2);
      expect(fair.totalWaste, 2);
      expect(fair.band, WasteBand.fair);
    });

    test('metroWasteDetail：末班后无班次 → 红', () {
      final detail = BestClockOutPlanner.metroWasteDetail(
        line: HanyuJinguMetro.lineWest,
        checkInMinutes: 8 * 60,
        departTime: 23 * 60,
      );
      expect(detail.hasTrain, isFalse);
      expect(detail.band, WasteBand.poor);
    });

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
