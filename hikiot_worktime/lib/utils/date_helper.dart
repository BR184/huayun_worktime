import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/constants.dart';
import '../services/storage_service.dart';

/// 日期工具类
/// 统一管理跨天时间点和日期格式化
class DateHelper {
  // 跨天时间点（分钟，默认04:00 = 240分钟）
  // 如果当前时间 < 跨天时间点，则认为还是"昨天"
  static int crossDayMinutes = 4 * 60; // 默认04:00

  // 是否已初始化
  static bool _initialized = false;

  /// 初始化（从设置加载跨天时间）
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settings = await StorageService().loadSettings();
      crossDayMinutes =
          settings[StorageKeys.crossDayMinutes] as int? ??
          AppConstants.defaultCrossDayMinutes;
      _initialized = true;
    } catch (e) {
      // Initialization error
    }
  }

  /// 重新加载配置（设置更改后调用）
  static Future<void> reload() async {
    _initialized = false;
    await initialize();
  }

  /// 保存跨天时间点
  static Future<void> saveCrossDayMinutes(int minutes) async {
    await StorageService().saveSettings({StorageKeys.crossDayMinutes: minutes});
    crossDayMinutes = minutes;
  }

  /// 获取跨天时间的TimeOfDay表示
  static TimeOfDay getCrossDayTime() {
    return TimeOfDay(hour: crossDayMinutes ~/ 60, minute: crossDayMinutes % 60);
  }

  /// 从TimeOfDay设置跨天时间
  static Future<void> setCrossDayTime(TimeOfDay time) async {
    await saveCrossDayMinutes(time.hour * 60 + time.minute);
  }

  /// 获取当前工作日日期
  /// 如果当前时间 < 跨天时间点，返回昨天日期
  static DateTime getWorkDate() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    if (currentMinutes < crossDayMinutes) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// 判断指定日期是否是当前工作日
  static bool isWorkToday(DateTime date) {
    final workDate = getWorkDate();
    return date.year == workDate.year &&
        date.month == workDate.month &&
        date.day == workDate.day;
  }

  /// 判断两个日期是否是同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  /// 获取跨天时间点的显示字符串
  static String getCrossDayTimeString() {
    final hour = crossDayMinutes ~/ 60;
    final minute = crossDayMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// TimeOfDay扩展
extension TimeOfDayExtension on TimeOfDay {
  /// 转换为分钟数
  int toMinutes() => hour * 60 + minute;
}
