/// 济南地铁 4 号线（汉峪金谷站）工作日时刻表模型。
///
/// 数据来源：用户提供的官方时刻表实测整理（2026-08-07）。
/// 规则化建模：每条方向线 = 首班 + 若干"起点~终点 + 间隔分钟"分段，
/// 段内按首班起等间隔生成（4.5 分钟间隔在真实表中表现为 +4/+5 交替，
/// 取整后与官方表最大偏差约 1-2 分钟，属用户接受的模型过渡差异）。
///
/// 已验证锚点（测试断言）：
/// - 方向① 14:02~14:32 平峰段与官方 App 实测逐班一致（6 分钟间隔）
/// - 方向① 末班 22:51、方向② 末班 23:25、方向③ 末班 19:58（20:00 后停运）
class MetroLineSegment {
  const MetroLineSegment({
    required this.startMinutes,
    required this.endMinutes,
    required this.intervalMinutes,
  });

  /// 段起点（当天第几分钟，00:00 起算）
  final int startMinutes;

  /// 段终点（含）
  final int endMinutes;

  /// 间隔分钟，支持 4.5 等半分钟
  final double intervalMinutes;
}

class MetroLine {
  const MetroLine({
    required this.name,
    required this.destination,
    required this.firstTime,
    required this.lastTime,
    required this.segments,
  });

  /// 方向名（如"第一医科大学"）
  final String name;

  /// 目的地描述（如"往西"）
  final String destination;

  /// 首班/末班时刻（HH:mm 字符串，用于展示）
  final String firstTime;
  final String lastTime;

  final List<MetroLineSegment> segments;

  /// 生成当天全部到站时刻（分钟，00:00 起算），已排序。
  List<int> times() {
    final result = <int>[];
    for (final segment in segments) {
      var t = segment.startMinutes.toDouble();
      while (t <= segment.endMinutes) {
        result.add(t.floor());
        t += segment.intervalMinutes;
      }
    }
    result.sort();
    return result;
  }

  /// 返回 [afterMinutes] 之后（含等于）最近一班到站时刻；无则 null。
  int? nextTrainAfter(int afterMinutes) {
    final times = this.times();
    for (final t in times) {
      if (t >= afterMinutes) return t;
    }
    return null;
  }
}

/// 汉峪金谷站三条方向线（工作日时刻表）。
class HanyuJinguMetro {
  HanyuJinguMetro._();

  /// 方向① 第一医科大学（往西）
  static const MetroLine lineWest = MetroLine(
    name: '第一医科大学',
    destination: '往西',
    firstTime: '06:02',
    lastTime: '22:51',
    segments: [
      // 平峰 6 分钟
      MetroLineSegment(
        startMinutes: 6 * 60 + 2,
        endMinutes: 7 * 60 + 2,
        intervalMinutes: 6,
      ),
      // 早高峰 4 分 30 秒
      MetroLineSegment(
        startMinutes: 7 * 60 + 2,
        endMinutes: 9 * 60 + 2,
        intervalMinutes: 4.5,
      ),
      // 平峰 6 分钟
      MetroLineSegment(
        startMinutes: 9 * 60 + 2,
        endMinutes: 17 * 60 + 2,
        intervalMinutes: 6,
      ),
      // 晚高峰 4 分 30 秒
      MetroLineSegment(
        startMinutes: 17 * 60 + 2,
        endMinutes: 19 * 60 + 32,
        intervalMinutes: 4.5,
      ),
      // 平峰过渡
      MetroLineSegment(
        startMinutes: 19 * 60 + 32,
        endMinutes: 19 * 60 + 56,
        intervalMinutes: 6,
      ),
      // 深夜间隔拉长
      MetroLineSegment(
        startMinutes: 19 * 60 + 56,
        endMinutes: 22 * 60 + 51,
        intervalMinutes: 7,
      ),
    ],
  );

  /// 方向② 彭家庄（往东，支线）
  static const MetroLine lineEastBranch = MetroLine(
    name: '彭家庄',
    destination: '往东（支线）',
    firstTime: '06:11',
    lastTime: '23:25',
    segments: [
      MetroLineSegment(
        startMinutes: 6 * 60 + 11,
        endMinutes: 7 * 60 + 5,
        intervalMinutes: 6,
      ),
      MetroLineSegment(
        startMinutes: 7 * 60 + 9,
        endMinutes: 8 * 60 + 57,
        intervalMinutes: 4.5,
      ),
      MetroLineSegment(
        startMinutes: 9 * 60 + 5,
        endMinutes: 17 * 60 + 5,
        intervalMinutes: 6,
      ),
      MetroLineSegment(
        startMinutes: 17 * 60 + 9,
        endMinutes: 19 * 60 + 29,
        intervalMinutes: 4.5,
      ),
      MetroLineSegment(
        startMinutes: 19 * 60 + 35,
        endMinutes: 19 * 60 + 59,
        intervalMinutes: 6,
      ),
      MetroLineSegment(
        startMinutes: 20 * 60 + 2,
        endMinutes: 23 * 60 + 25,
        intervalMinutes: 7,
      ),
    ],
  );

  /// 方向③ 清源大街（往东，贯通 8 号线，20:00 后停运）
  static const MetroLine lineEastThrough = MetroLine(
    name: '清源大街',
    destination: '往东（8 号线贯通）',
    firstTime: '06:04',
    lastTime: '19:58',
    segments: [
      MetroLineSegment(
        startMinutes: 6 * 60 + 4,
        endMinutes: 7 * 60 + 4,
        intervalMinutes: 6,
      ),
      MetroLineSegment(
        startMinutes: 7 * 60 + 8,
        endMinutes: 8 * 60 + 56,
        intervalMinutes: 4.5,
      ),
      MetroLineSegment(
        startMinutes: 9 * 60 + 4,
        endMinutes: 17 * 60 + 4,
        intervalMinutes: 6,
      ),
      MetroLineSegment(
        startMinutes: 17 * 60 + 8,
        endMinutes: 19 * 60 + 28,
        intervalMinutes: 4.5,
      ),
      MetroLineSegment(
        startMinutes: 19 * 60 + 34,
        endMinutes: 19 * 60 + 58,
        intervalMinutes: 6,
      ),
    ],
  );

  /// 全部方向线（顺序即选择顺序）
  static const List<MetroLine> lines = [
    lineWest,
    lineEastBranch,
    lineEastThrough,
  ];
}
