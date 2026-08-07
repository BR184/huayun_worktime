import '../data/metro_schedule.dart';
import 'work_time_calculator.dart';

/// 出行方式。
enum CommuteMode {
  /// 自由出行（开车/骑车），无外部时刻表约束
  free,

  /// 地铁（汉峪金谷站，固定时刻表）
  metro,

  /// 公交（后续接入车来了实时数据）
  bus,
}

/// 工时浪费档位（按百分位残差分档）。
///
/// 残差 = 工时显示两位与计入一位的差值（0.00~0.09）：
/// - best：0.00~0.02，浪费 0~1.2 分钟
/// - fair：0.03~0.05，浪费 1.8~3 分钟
/// - poor：0.06~0.09，浪费 3.6~5.4 分钟
enum WasteBand { best, fair, poor }

/// 到达地铁站所需步行分钟（公司门口到站台）。
const int metroWalkMinutes = 6;

/// 地铁模式候选班次的评估结果。
class MetroPlan {
  const MetroPlan({
    required this.departTime,
    required this.trainTime,
    required this.band,
    required this.wasteMinutes,
    required this.waitMinutes,
    required this.score,
  });

  /// 建议下班时刻（第几分钟）
  final int departTime;

  /// 对应地铁班次到站时刻（第几分钟）
  final int trainTime;

  final WasteBand band;

  /// 工时浪费分钟（残差 × 60，保留一位）
  final double wasteMinutes;

  /// 距现在的等待分钟
  final int waitMinutes;

  /// 性价比得分 = 工时浪费分钟 + 等待分钟，越小越好
  final double score;
}

/// 最佳下班时间规划器（纯函数，可单测）。
///
/// 模式说明：
/// - 自由出行：只按工时百分位残差分档，无时刻表约束；
/// - 地铁：固定时刻表 + 提前 [metroWalkMinutes] 分钟到站，
///   对每个候选班次综合"工时浪费 + 等待"取性价比最高。
class BestClockOutPlanner {
  BestClockOutPlanner._();

  /// 百分位残差分档。
  static WasteBand bandOf(double fraction) {
    if (fraction <= 0.02) return WasteBand.best;
    if (fraction <= 0.05) return WasteBand.fair;
    return WasteBand.poor;
  }

  /// 当前时刻的浪费分钟（残差 × 60，保留一位）。
  ///
  /// 用整数运算避免浮点下界（0.09 × 60 = 5.3999…）。
  static double wasteMinutesOf(double fraction) {
    return (fraction * 600).truncate() / 10;
  }

  /// 自由模式：下一个"最佳档"下班时刻。
  ///
  /// 残差 ≤0.02 即浪费 ≤1.2 分钟；整点（十分位为 0）残差为 0，
  /// 其后 72 秒内都属最佳档，这里直接取下一个整十分位时刻。
  static int nextBestFreeTime(int checkInMinutes, int nowMinutes) {
    final elapsed = nowMinutes - checkInMinutes;
    // 0.1h = 6 分钟一个整点；从 now 往后推到下一个 6 分钟倍数
    final wait = (6 - elapsed % 6) % 6;
    return nowMinutes + wait;
  }

  /// 地铁模式：评估全部剩余候选班次，返回性价比最高者。
  ///
  /// 候选 = 今天剩余班次中，下班时刻（班次 - 6 分钟）不早于现在。
  /// 得分 = 工时浪费分钟 + 等待分钟；同得分取残差更小者。
  static MetroPlan? bestMetroPlan({
    required MetroLine line,
    required int checkInMinutes,
    required int nowMinutes,
  }) {
    final times = line.times();
    MetroPlan? best;
    for (final trainTime in times) {
      final departTime = trainTime - metroWalkMinutes;
      if (departTime < nowMinutes) continue;
      final elapsed = departTime - checkInMinutes;
      final hours = elapsed / 60.0;
      final fraction = WorkTimeCalculator.wastedFraction(hours);
      final band = bandOf(fraction);
      final waste = wasteMinutesOf(fraction);
      final wait = departTime - nowMinutes;
      final score = waste + wait;
      if (best == null ||
          score < best.score ||
          (score == best.score && waste < best.wasteMinutes)) {
        best = MetroPlan(
          departTime: departTime,
          trainTime: trainTime,
          band: band,
          wasteMinutes: waste,
          waitMinutes: wait,
          score: score,
        );
      }
    }
    return best;
  }

  /// 地铁模式：现在下班能赶上的最近班次（残差分档用）。
  static MetroPlan? currentMetroCatch({
    required MetroLine line,
    required int checkInMinutes,
    required int nowMinutes,
  }) {
    final trainTime = line.nextTrainAfter(nowMinutes + metroWalkMinutes);
    if (trainTime == null) return null;
    final departTime = trainTime - metroWalkMinutes;
    final elapsed = departTime - checkInMinutes;
    final hours = elapsed / 60.0;
    final fraction = WorkTimeCalculator.wastedFraction(hours);
    return MetroPlan(
      departTime: departTime,
      trainTime: trainTime,
      band: bandOf(fraction),
      wasteMinutes: wasteMinutesOf(fraction),
      waitMinutes: 0,
      score: 0,
    );
  }
}
