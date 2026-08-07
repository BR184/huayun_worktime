import '../core/constants/constants.dart';
import '../services/storage_service.dart';

/// 工时计算工具类
/// 统一管理午休扣除逻辑和工时计算
class WorkTimeCalculator {
  // 默认午休时间配置
  static const String defaultLunchStart = '12:00';
  static const String defaultLunchEnd = '13:00';
  static const int defaultLunchDurationMinutes = 60;

  // 默认午休时间（分钟表示，方便计算）
  static int lunchStartMinutes = 12 * 60; // 12:00 = 720分钟
  static int lunchEndMinutes = 13 * 60; // 13:00 = 780分钟

  // 是否已初始化
  static bool _initialized = false;

  /// 初始化午休时间配置（从设置加载）
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settings = await StorageService().loadSettings();
      final lunchStart = settings[StorageKeys.lunchStartTime] as String?;
      final lunchEnd = settings[StorageKeys.lunchEndTime] as String?;

      if (lunchStart != null) {
        final minutes = parseTimeToMinutes(lunchStart);
        if (minutes != null) lunchStartMinutes = minutes;
      }

      if (lunchEnd != null) {
        final minutes = parseTimeToMinutes(lunchEnd);
        if (minutes != null) lunchEndMinutes = minutes;
      }

      _initialized = true;
    } catch (e) {
      // Initialization error - use defaults
    }
  }

  /// 重新加载配置（设置更改后调用）
  static Future<void> reload() async {
    _initialized = false;
    await initialize();
  }

  /// 获取当前午休时长（分钟）
  static int get lunchDurationMinutes {
    final duration = lunchEndMinutes - lunchStartMinutes;
    return duration > 0 ? duration : 0;
  }

  /// 判断是否应该扣除午休时间
  /// 规则：上班时间 < 午休开始 且 下班时间 > 午休结束 时才扣除
  ///
  /// [checkInMinutes] 上班时间（分钟，如 8:30 = 510）
  /// [checkOutMinutes] 下班时间（分钟，如 17:30 = 1050）
  ///
  /// 返回：是否需要扣除午休
  static bool shouldDeductLunch(int checkInMinutes, int checkOutMinutes) {
    if (lunchEndMinutes <= lunchStartMinutes) return false;
    final comparableCheckOut = _comparableCheckOutMinutes(
      checkInMinutes,
      checkOutMinutes,
    );
    return checkInMinutes < lunchStartMinutes &&
        comparableCheckOut > lunchEndMinutes;
  }

  /// 判断是否应该扣除午休时间（字符串版本）
  ///
  /// [checkIn] 上班时间，格式 "HH:mm"
  /// [checkOut] 下班时间，格式 "HH:mm"
  ///
  /// 返回：是否需要扣除午休
  static bool shouldDeductLunchStr(String checkIn, String checkOut) {
    final inMinutes = parseTimeToMinutes(checkIn);
    final outMinutes = parseTimeToMinutes(checkOut);

    if (inMinutes == null || outMinutes == null) return false;

    return shouldDeductLunch(inMinutes, outMinutes);
  }

  /// 计算实际需要扣除的午休分钟数
  /// 考虑部分重叠的情况（为将来扩展预留）
  ///
  /// [checkInMinutes] 上班时间（分钟）
  /// [checkOutMinutes] 下班时间（分钟）
  ///
  /// 返回：需要扣除的分钟数
  static int getLunchDeductionMinutes(int checkInMinutes, int checkOutMinutes) {
    if (shouldDeductLunch(checkInMinutes, checkOutMinutes)) {
      return lunchDurationMinutes;
    }
    return 0;
  }

  /// 计算工时（分钟）
  ///
  /// [checkInMinutes] 上班时间（分钟）
  /// [checkOutMinutes] 下班时间（分钟）
  /// [deductLunch] 是否扣除午休，默认自动判断
  ///
  /// 返回：工时分钟数
  static int calculateWorkMinutes(
    int checkInMinutes,
    int checkOutMinutes, {
    bool? deductLunch,
  }) {
    final comparableCheckOut = _comparableCheckOutMinutes(
      checkInMinutes,
      checkOutMinutes,
    );

    // 处理下班时间在午休期间的情况：截断到12:00
    int effectiveCheckOut = checkOutMinutes;
    if (checkInMinutes < lunchStartMinutes &&
        comparableCheckOut >= lunchStartMinutes &&
        comparableCheckOut <= lunchEndMinutes) {
      effectiveCheckOut = lunchStartMinutes;
    }

    // 处理上班时间在午休期间的情况：截断到13:00
    int effectiveCheckIn = checkInMinutes;
    if (checkInMinutes >= lunchStartMinutes &&
        checkInMinutes <= lunchEndMinutes &&
        comparableCheckOut > lunchEndMinutes) {
      effectiveCheckIn = lunchEndMinutes;
    }

    var totalMinutes = effectiveCheckOut - effectiveCheckIn;

    // 处理跨天情况
    if (totalMinutes < 0) {
      totalMinutes += 24 * 60;
    }

    // 判断是否扣除午休（上班<午休开始且下班>午休结束）
    final shouldDeduct =
        deductLunch ?? shouldDeductLunch(effectiveCheckIn, effectiveCheckOut);
    if (shouldDeduct) {
      totalMinutes -= lunchDurationMinutes;
    }

    return totalMinutes;
  }

  static int _comparableCheckOutMinutes(
    int checkInMinutes,
    int checkOutMinutes,
  ) {
    if (checkOutMinutes < checkInMinutes) {
      return checkOutMinutes + 24 * 60;
    }
    return checkOutMinutes;
  }

  /// 计算工时（小时，保留2位小数）
  ///
  /// [checkInMinutes] 上班时间（分钟）
  /// [checkOutMinutes] 下班时间（分钟）
  /// [deductLunch] 是否扣除午休，默认自动判断
  ///
  /// 返回：工时小时数（截断到2位小数）
  static double calculateWorkHours(
    int checkInMinutes,
    int checkOutMinutes, {
    bool? deductLunch,
  }) {
    final minutes = calculateWorkMinutes(
      checkInMinutes,
      checkOutMinutes,
      deductLunch: deductLunch,
    );
    final hours = minutes / 60.0;
    // 截断到2位小数
    return (hours * 100).truncateToDouble() / 100;
  }

  /// 从字符串计算工时（小时）
  ///
  /// [checkIn] 上班时间，格式 "HH:mm"
  /// [checkOut] 下班时间，格式 "HH:mm"
  /// [deductLunch] 是否扣除午休，默认自动判断
  ///
  /// 返回：工时小时数（截断到2位小数），解析失败返回0.0
  static double calculateWorkHoursStr(
    String checkIn,
    String checkOut, {
    bool? deductLunch,
  }) {
    final inMinutes = parseTimeToMinutes(checkIn);
    final outMinutes = parseTimeToMinutes(checkOut);

    if (inMinutes == null || outMinutes == null) return 0.0;

    return calculateWorkHours(inMinutes, outMinutes, deductLunch: deductLunch);
  }

  /// 解析时间字符串为分钟数
  ///
  /// [timeStr] 时间字符串，格式 "HH:mm" 或 "HH:MM:SS"
  ///
  /// 返回：从0点开始的分钟数，解析失败返回null
  static int? parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return hour * 60 + minute;
    } catch (e) {
      return null;
    }
  }

  /// 将分钟数转换为时间字符串
  ///
  /// [minutes] 从0点开始的分钟数
  ///
  /// 返回：格式 "HH:mm"
  static String minutesToTimeStr(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// 获取实际计入统计的工时。
  ///
  /// 公司口径只统计到十分位，百分位及之后直接截断，不四舍五入。
  static double billableHours(num hours) {
    return (hours.toDouble() * 10).truncateToDouble() / 10;
  }

  /// 被截断掉的百分位工时（显示两位与计入一位的差值）。
  ///
  /// 例如 8.04 显示为 8.03 镂空 0.04 时，计入 8.0，残差为 0.04；
  /// 月度页"无效工时"即所有天的残差累计。
  /// 用整数运算避免浮点误差（8.04 * 100 会得到 804.000...1）。
  static double wastedFraction(num hours) {
    final hundredths = (hours.toDouble() * 100).truncate();
    final tenths = (hours.toDouble() * 10).truncate() * 10;
    return (hundredths - tenths) / 100;
  }

  /// 按统一口径计算工时百分比。
  ///
  /// 参与统计的工时先截断到一位小数，再计算百分比；
  /// 百分比是计算输出，不受"工时限一位"影响，结果保留两位小数
  /// （截断，不四舍五入）。
  static double calculatePercentage({
    required num hours,
    required num baseHours,
    double? min,
    double? max,
  }) {
    final base = baseHours.toDouble();
    if (base <= 0) return 0.0;

    final percentage = _truncateToTwoDecimals(
      billableHours(hours) / base * 100,
    );
    if (min == null && max == null) return percentage;
    return percentage.clamp(
      min ?? double.negativeInfinity,
      max ?? double.infinity,
    );
  }

  /// 截断到两位小数（不四舍五入）。
  static double _truncateToTwoDecimals(double value) {
    return (value * 100).truncateToDouble() / 100;
  }

  /// 下一个工时"凑整"时刻（十分位为 0，即工时 X.X0h）。
  ///
  /// 工时精度截断到一位后，百分位会被浪费（如 11.19h 只计 11.1h）；
  /// "最佳下班时间"功能据此推荐在工时刚好为整十分位的时刻下班。
  /// 0.1h = 6 分钟，因此从当前时刻往后推到下一个 6 分钟倍数。
  static DateTime nextWholeTenthTime(DateTime checkIn, DateTime now) {
    final elapsedMinutes = now.difference(checkIn).inMinutes;
    final waitMinutes = (6 - elapsedMinutes % 6) % 6;
    return now.add(Duration(minutes: waitMinutes));
  }

  /// 格式化两次打卡之间的原始时长，不扣除午休。
  static String formatPunchDuration(String? checkIn, String? checkOut) {
    final inMinutes = parseTimeToMinutes(checkIn);
    final outMinutes = parseTimeToMinutes(checkOut);
    if (inMinutes == null || outMinutes == null) return '--';

    var durationMinutes = outMinutes - inMinutes;
    if (durationMinutes < 0) {
      durationMinutes += 24 * 60;
    }
    return '${formatHours(durationMinutes / 60.0)}小时';
  }

  /// 无法使用富文本的系统通知使用一位小数，避免百分位被误认为计入工时。
  static String formatBillableHours(num hours) {
    return billableHours(hours).toStringAsFixed(1);
  }

  /// 格式化工时显示
  ///
  /// [hours] 工时小时数
  ///
  /// 返回：格式化的字符串，如 "8.55" (直接截断2位，不四舍五入)
  static String formatHours(num hours) {
    // 整数保持紧凑显示；浮点运算结果保留两位小数，直接截断不四舍五入。
    // 例如: 8 -> 8
    if (hours is int) {
      return hours.toString();
    }

    // 例如: 8.0 -> 8.00
    // 例如: 5.559 (double) -> 5.55
    final h = hours.toDouble();
    final truncated = (h * 100).truncateToDouble() / 100;
    return truncated.toStringAsFixed(2);
  }

  // ========== 目标管理逻辑 (KISS: 复用此类) ==========

  /// 生成目标列表，确保包含基础目标
  static List<int> generateTargetList(int baseTarget) {
    final targets = <int>{100, 110, 120, 130, 140, 150, 160};
    targets.add(baseTarget); // 确保基础目标在列表中
    final sortedList = targets.toList()..sort();
    return sortedList;
  }

  /// 计算新的置顶目标（切换逻辑）
  ///
  /// [currentTarget] 当前置顶目标
  /// [targetToToggle] 想要切换的目标
  ///
  /// 返回：新的置顶目标（如果相同则取消置顶返回null，否则返回新目标）
  static int? calculateNewPinnedTarget(int? currentTarget, int targetToToggle) {
    return currentTarget == targetToToggle ? null : targetToToggle;
  }
}
