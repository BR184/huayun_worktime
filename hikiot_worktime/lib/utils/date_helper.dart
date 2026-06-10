import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/constants.dart';
import '../services/storage_service.dart';

/// 日期工具类
///
/// 注意：跨天时间点只用于“跨天打卡提醒”，不再改变 APP 的当前工作日。
/// 海康每日接口按自然日返回数据，APP 自动把凌晨打卡并入上一日会制造错误归属。
class DateHelper {
  // 跨天提醒截止时间（分钟，默认 04:00 = 240 分钟）
  static int crossDayMinutes = 4 * 60;

  static bool _initialized = false;

  /// 初始化提醒时间配置
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settings = await StorageService().loadSettings();
      crossDayMinutes =
          settings[StorageKeys.crossDayMinutes] as int? ??
          AppConstants.defaultCrossDayMinutes;
      _initialized = true;
    } catch (e) {
      // 初始化失败时保留默认提醒时间
    }
  }

  /// 重新加载配置（设置更改后调用）
  static Future<void> reload() async {
    _initialized = false;
    await initialize();
  }

  /// 保存跨天提醒截止时间
  static Future<void> saveCrossDayMinutes(int minutes) async {
    await StorageService().saveSettings({StorageKeys.crossDayMinutes: minutes});
    crossDayMinutes = minutes;
  }

  /// 获取跨天提醒时间的 TimeOfDay 表示
  static TimeOfDay getCrossDayTime() {
    return TimeOfDay(hour: crossDayMinutes ~/ 60, minute: crossDayMinutes % 60);
  }

  /// 从 TimeOfDay 设置跨天提醒时间
  static Future<void> setCrossDayTime(TimeOfDay time) async {
    await saveCrossDayMinutes(time.hour * 60 + time.minute);
  }

  /// 获取当前自然日。
  ///
  /// 以前这里会在跨天时间点前返回昨天；现在关闭自动跨天归属。
  static DateTime getWorkDate({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    return DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
  }

  /// 判断指定日期是否是今天（自然日）
  static bool isWorkToday(DateTime date, {DateTime? now}) {
    final today = getWorkDate(now: now);
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// 判断两个日期是否是同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断打卡时间是否落在跨天提醒窗口内。
  ///
  /// 窗口为 00:00 之后、跨天提醒截止时间之前；用于提醒用户手动调整工时。
  static bool isCrossDayReminderPunchTime(String? timeStr) {
    final minutes = _parseTimeToMinutes(timeStr);
    return minutes != null && minutes > 0 && minutes < crossDayMinutes;
  }

  /// 从一组打卡时间中找出最早的跨天提醒时间
  static String? firstCrossDayReminderPunchTime(Iterable<String?> times) {
    String? result;
    int? earliestMinutes;

    for (final time in times) {
      final minutes = _parseTimeToMinutes(time);
      if (minutes == null || minutes <= 0 || minutes >= crossDayMinutes) {
        continue;
      }

      if (earliestMinutes == null || minutes < earliestMinutes) {
        earliestMinutes = minutes;
        result = time;
      }
    }

    return result;
  }

  /// 格式化日期为 yyyy-MM-dd
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// 格式化月份为 yyyy-MM
  static String formatMonth(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  /// 格式化日期为中文显示 yyyy年MM月dd日 星期X
  static String formatDateChinese(DateTime date) {
    return DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(date);
  }

  /// 格式化时间为 HH:mm
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// 获取跨天提醒时间点的显示字符串
  static String getCrossDayTimeString() {
    final hour = crossDayMinutes ~/ 60;
    final minute = crossDayMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int? _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '-') return null;

    final parts = timeStr.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }
}

/// TimeOfDay 扩展
extension TimeOfDayExtension on TimeOfDay {
  /// 转换为分钟数
  int toMinutes() => hour * 60 + minute;
}
