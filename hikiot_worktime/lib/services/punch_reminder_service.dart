import 'notification_service.dart';
import 'reminder_attendance_fetcher.dart';
import '../utils/attendance_parser.dart';
import '../utils/reminder_day_policy.dart';
import '../utils/work_time_calculator.dart';

/// 打卡提醒检测服务
class PunchReminderService {
  /// 检查上班打卡
  static Future<void> checkMorningPunch() async {
    final notification = NotificationService();
    await notification.initialize();

    try {
      // 检查是否法定节假日
      if (await _isLegalHoliday()) {
        return; // 法定节假日不提醒
      }

      // 尝试联网获取今日考勤
      final result = await _fetchTodayAttendanceWithStatus();
      final attendance = result['data'] as Map<String, dynamic>?;
      final isTokenExpired = result['tokenExpired'] as bool;

      if (isTokenExpired) {
        // Token失效，提示用户重新登录
        await notification.showNotification(
          id: 101,
          title: '⚠️ 登录已过期',
          body: '请打开App重新登录后查看打卡状态',
        );
        return;
      }

      if (attendance == null) {
        // 无网络，发送通用提醒
        await notification.showNotification(
          id: 101,
          title: '上班打卡提醒',
          body: '记得检查今天的打卡状态哦~',
        );
        return;
      }

      // 解析打卡状态
      final checkInTime = _getCheckInTime(attendance);

      if (checkInTime == null) {
        await notification.showNotification(
          id: 101,
          title: '上班打卡提醒',
          body: '今天还没有打上班卡，别忘了打卡！',
        );
      } else {
        // 已打卡，显示打卡时间
        await notification.showNotification(
          id: 101,
          title: '上班打卡状态',
          body: '已打上班卡：$checkInTime',
        );
      }
    } catch (e) {
      // 出错时发送通用提醒
      await notification.showNotification(
        id: 101,
        title: '上班打卡提醒',
        body: '记得检查今天的打卡状态哦~',
      );
    }
  }

  /// 检查下班打卡
  static Future<void> checkEveningPunch() async {
    final notification = NotificationService();
    await notification.initialize();

    try {
      // 检查是否法定节假日
      if (await _isLegalHoliday()) {
        return;
      }

      // 尝试联网获取今日考勤
      final result = await _fetchTodayAttendanceWithStatus();
      final attendance = result['data'] as Map<String, dynamic>?;
      final isTokenExpired = result['tokenExpired'] as bool;

      if (isTokenExpired) {
        // Token失效，提示用户重新登录
        await notification.showNotification(
          id: 102,
          title: '⚠️ 登录已过期',
          body: '请打开App重新登录后查看打卡和工时状态',
        );
        return;
      }

      if (attendance == null) {
        // 无网络，发送通用提醒
        await notification.showNotification(
          id: 102,
          title: '下班打卡提醒',
          body: '记得检查今天的打卡和工时状态~',
        );
        return;
      }

      // 解析打卡状态和工时
      final checkOutTime = _getCheckOutTime(attendance);
      final workHours = _getWorkHours(attendance);

      if (checkOutTime == null) {
        await notification.showNotification(
          id: 102,
          title: '下班打卡提醒',
          body: '今天还没有打下班卡，别忘了打卡！',
        );
      } else if (WorkTimeCalculator.billableHours(workHours) < 8) {
        // 已打卡但工时不足
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态',
          body:
              '已打下班卡：$checkOutTime，工时 ${WorkTimeCalculator.formatBillableHours(workHours)} 小时不足8H',
        );
      } else {
        // 已打卡且工时充足
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态',
          body:
              '已打下班卡：$checkOutTime，工时 ${WorkTimeCalculator.formatBillableHours(workHours)} 小时',
        );
      }
    } catch (e) {
      await notification.showNotification(
        id: 102,
        title: '下班打卡提醒',
        body: '记得检查今天的打卡和工时状态~',
      );
    }
  }

  /// 发送测试通知（完整测试流程）
  /// 1. 立即发送测试成功通知
  /// 2. 1秒后强制触发上班打卡提醒
  /// 3. 再1秒后强制触发下班打卡提醒
  static Future<void> sendTestNotification() async {
    final notification = NotificationService();
    await notification.initialize();

    // 第一步：发送测试成功通知
    await notification.showNotification(
      id: 100,
      title: '🔔 测试通知 (1/3)',
      body: '提醒功能测试中，接下来将模拟上班和下班提醒...',
    );

    // 第二步：1秒后触发上班打卡提醒（强制触发，不检查节假日）
    await Future.delayed(const Duration(seconds: 1));
    await _sendMorningPunchNotificationForTest();

    // 第三步：再1秒后触发下班打卡提醒（强制触发，不检查节假日）
    await Future.delayed(const Duration(seconds: 1));
    await _sendEveningPunchNotificationForTest();
  }

  /// 测试用：强制发送上班打卡提醒（不检查节假日）
  static Future<void> _sendMorningPunchNotificationForTest() async {
    final notification = NotificationService();
    await notification.initialize();

    try {
      final result = await _fetchTodayAttendanceWithStatus();
      final attendance = result['data'] as Map<String, dynamic>?;
      final isTokenExpired = result['tokenExpired'] as bool;

      if (isTokenExpired) {
        await notification.showNotification(
          id: 101,
          title: '⚠️ 上班提醒测试 (2/3)',
          body: '登录已过期，请重新登录',
        );
        return;
      }

      if (attendance == null) {
        await notification.showNotification(
          id: 101,
          title: '上班打卡提醒 (2/3)',
          body: '记得检查今天的打卡状态哦~',
        );
        return;
      }

      final checkInTime = _getCheckInTime(attendance);
      if (checkInTime == null) {
        await notification.showNotification(
          id: 101,
          title: '上班打卡提醒 (2/3)',
          body: '今天还没有打上班卡，别忘了打卡！',
        );
      } else {
        await notification.showNotification(
          id: 101,
          title: '上班打卡状态 (2/3)',
          body: '已打上班卡：$checkInTime',
        );
      }
    } catch (e) {
      await notification.showNotification(
        id: 101,
        title: '上班打卡提醒 (2/3)',
        body: '记得检查今天的打卡状态哦~',
      );
    }
  }

  /// 测试用：强制发送下班打卡提醒（不检查节假日）
  static Future<void> _sendEveningPunchNotificationForTest() async {
    final notification = NotificationService();
    await notification.initialize();

    try {
      final result = await _fetchTodayAttendanceWithStatus();
      final attendance = result['data'] as Map<String, dynamic>?;
      final isTokenExpired = result['tokenExpired'] as bool;

      if (isTokenExpired) {
        await notification.showNotification(
          id: 102,
          title: '⚠️ 下班提醒测试 (3/3)',
          body: '登录已过期，请重新登录',
        );
        return;
      }

      if (attendance == null) {
        await notification.showNotification(
          id: 102,
          title: '下班打卡提醒 (3/3)',
          body: '记得检查今天的打卡和工时状态~',
        );
        return;
      }

      final checkOutTime = _getCheckOutTime(attendance);
      final workHours = _getWorkHours(attendance);

      if (checkOutTime == null) {
        await notification.showNotification(
          id: 102,
          title: '下班打卡提醒 (3/3)',
          body: '今天还没有打下班卡，别忘了打卡！',
        );
      } else if (WorkTimeCalculator.billableHours(workHours) < 8.0) {
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态 (3/3)',
          body:
              '已打下班卡：$checkOutTime，工时 ${WorkTimeCalculator.formatBillableHours(workHours)} 小时不足8H',
        );
      } else {
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态 (3/3)',
          body:
              '已打下班卡：$checkOutTime，工时 ${WorkTimeCalculator.formatBillableHours(workHours)} 小时',
        );
      }
    } catch (e) {
      await notification.showNotification(
        id: 102,
        title: '下班打卡提醒 (3/3)',
        body: '记得检查今天的打卡和工时状态~',
      );
    }
  }

  /// 获取今日考勤数据（带Token状态）
  /// 返回 {'data': Map?, 'tokenExpired': bool}
  static Future<Map<String, dynamic>> _fetchTodayAttendanceWithStatus() async {
    final result = await ReminderAttendanceFetcher().fetchToday();
    return {'data': result.data, 'tokenExpired': result.tokenExpired};
  }

  /// 获取上班打卡时间 - 使用 AttendanceParser 统一解析
  static String? _getCheckInTime(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return null;

    final parsed = AttendanceParser.parse(dailyDetail);
    if (parsed.checkIn != null &&
        parsed.checkIn!.isNotEmpty &&
        parsed.checkIn != '-') {
      return parsed.checkIn;
    }
    return null;
  }

  /// 获取下班打卡时间 - 使用 AttendanceParser 统一解析
  static String? _getCheckOutTime(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return null;

    final parsed = AttendanceParser.parse(dailyDetail);
    if (parsed.checkOut != null &&
        parsed.checkOut!.isNotEmpty &&
        parsed.checkOut != '-') {
      return parsed.checkOut;
    }
    return null;
  }

  /// 获取工时 - 使用 AttendanceParser 统一解析
  static double _getWorkHours(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return 0;

    // 使用统一的解析器
    final parsed = AttendanceParser.parse(dailyDetail);
    return parsed.hours;
  }

  /// 检查是否为休息日（不需要提醒）
  /// 休息日包括：法定节假日、普通周末（非调休）
  static Future<bool> _isLegalHoliday() async {
    return ReminderDayPolicy().shouldSkipWorkReminder(DateTime.now());
  }
}
