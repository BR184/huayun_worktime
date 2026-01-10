import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('settings');

      if (settingsJson != null) {
        final settings = Map<String, dynamic>.from(jsonDecode(settingsJson));

        final lunchStart = settings['lunchStartTime'] as String?;
        final lunchEnd = settings['lunchEndTime'] as String?;

        if (lunchStart != null) {
          final minutes = parseTimeToMinutes(lunchStart);
          if (minutes != null) lunchStartMinutes = minutes;
        }

        if (lunchEnd != null) {
          final minutes = parseTimeToMinutes(lunchEnd);
          if (minutes != null) lunchEndMinutes = minutes;
        }
      }

      _initialized = true;
    } catch (e) {
      print('WorkTimeCalculator初始化失败: $e');
    }
  }

  /// 重新加载配置（设置更改后调用）
  static Future<void> reload() async {
    _initialized = false;
    await initialize();
  }

  /// 获取当前午休时长（分钟）
  static int get lunchDurationMinutes => lunchEndMinutes - lunchStartMinutes;

  /// 判断是否应该扣除午休时间
  /// 规则：上班时间 < 午休开始 且 下班时间 > 午休结束 时才扣除
  ///
  /// [checkInMinutes] 上班时间（分钟，如 8:30 = 510）
  /// [checkOutMinutes] 下班时间（分钟，如 17:30 = 1050）
  ///
  /// 返回：是否需要扣除午休
  static bool shouldDeductLunch(int checkInMinutes, int checkOutMinutes) {
    return checkInMinutes < lunchStartMinutes &&
        checkOutMinutes > lunchEndMinutes;
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
      return defaultLunchDurationMinutes;
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
    // 处理下班时间在午休期间的情况：截断到12:00
    int effectiveCheckOut = checkOutMinutes;
    if (checkInMinutes < lunchStartMinutes &&
        checkOutMinutes >= lunchStartMinutes &&
        checkOutMinutes <= lunchEndMinutes) {
      effectiveCheckOut = lunchStartMinutes;
    }

    // 处理上班时间在午休期间的情况：截断到13:00
    int effectiveCheckIn = checkInMinutes;
    if (checkInMinutes >= lunchStartMinutes &&
        checkInMinutes <= lunchEndMinutes &&
        checkOutMinutes > lunchEndMinutes) {
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

  /// 格式化工时显示
  ///
  /// [hours] 工时小时数
  ///
  /// 返回：格式化的字符串，如 "8.50"
  static String formatHours(double hours) {
    return hours.toStringAsFixed(2);
  }
}
