import 'dart:math';

/// DEBUG 时间模拟器（仅内存态，不影响任何真实数据）。
///
/// 用途：开发时验证"最佳下班时间"与打卡序列在不同时段下的表现。
/// 开启后 [now] 返回模拟时钟（随真实时间同步走秒），关闭后恢复真实时间。
/// 打卡序列只用于展示层覆盖，不写入存储。
class MockTimeService {
  MockTimeService._();

  static final MockTimeService instance = MockTimeService._();

  /// 模拟基准时间；null = 未启用
  DateTime? _base;

  /// 设定基准时的真实时间（用于让模拟时钟同步走秒）
  DateTime? _realAtSet;

  /// 模拟打卡序列（HH:mm，含首次与最后一次）
  List<String> _punches = [];

  bool get isMocked => _base != null;

  /// 当前（模拟）时间；未启用时返回真实时间
  DateTime now() {
    final base = _base;
    if (base == null) return DateTime.now();
    return base.add(DateTime.now().difference(_realAtSet!));
  }

  /// 设置模拟基准时间（拖动条/随机按钮调用）
  void setMock(DateTime time) {
    _base = time;
    _realAtSet = DateTime.now();
  }

  /// 设置模拟打卡序列
  void setPunches(List<String> punches) {
    _punches = List.of(punches);
  }

  List<String> get punches => List.of(_punches);

  /// 关闭模拟，恢复真实时间与真实数据
  void clear() {
    _base = null;
    _realAtSet = null;
    _punches = [];
  }
}

/// 随机模拟数据生成器（纯函数，可单测）。
class MockPunchGenerator {
  MockPunchGenerator._();

  static final Random _random = Random();

  /// 生成 8:00~23:00 之间的随机模拟时间（今天日期）。
  static DateTime randomTime() {
    final now = DateTime.now();
    final hour = 8 + _random.nextInt(16); // 8..23
    final minute = _random.nextInt(60);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// 生成打卡序列：
  /// - 首次打卡 6:00~9:00 随机，且必早于模拟时间；
  /// - 中间 0~3 次随机进出（在首次与最后一次之间）；
  /// - 最后一次晚于首次且不晚于 [mockNow]。
  static List<String> randomPunches(DateTime mockNow) {
    final nowMinutes = mockNow.hour * 60 + mockNow.minute;
    // 首次打卡上限：08:59 与 模拟时间前 1 分钟 的较小值
    final firstMax = min(8 * 60 + 59, nowMinutes - 1);
    if (firstMax < 6 * 60) return []; // 模拟时间早于 6 点（本工具范围 8~23 不会触发）
    final firstMinute = 6 * 60 + _random.nextInt(firstMax - 6 * 60 + 1);

    final span = max(1, nowMinutes - firstMinute);
    final lastMinute = min(firstMinute + 1 + _random.nextInt(span), nowMinutes);

    final punches = <int>[firstMinute];
    final middleCount = _random.nextInt(4); // 0..3 次中间进出
    for (var i = 0; i < middleCount; i++) {
      final middle =
          firstMinute +
          1 +
          _random.nextInt(max(1, lastMinute - firstMinute - 1));
      punches.add(middle);
    }
    punches.add(lastMinute);
    punches.sort();

    return punches.map(_toTimeText).toList();
  }

  /// 今天对应日期的星期名（用于展示模拟星期）
  static String weekdayName(DateTime time) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[time.weekday - 1];
  }

  static String _toTimeText(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
