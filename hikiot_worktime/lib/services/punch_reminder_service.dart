import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/constants.dart';
import 'notification_service.dart';
import '../utils/attendance_parser.dart';

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
      } else if (workHours < 8.0) {
        // 已打卡但工时不足
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态',
          body: '已打下班卡：$checkOutTime，工时 ${_formatHours(workHours)} 小时不足8H',
        );
      } else {
        // 已打卡且工时充足
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态',
          body: '已打下班卡：$checkOutTime，工时 ${_formatHours(workHours)} 小时',
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
      } else if (workHours < 8.0) {
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态 (3/3)',
          body: '已打下班卡：$checkOutTime，工时 ${_formatHours(workHours)} 小时不足8H',
        );
      } else {
        await notification.showNotification(
          id: 102,
          title: '下班打卡状态 (3/3)',
          body: '已打下班卡：$checkOutTime，工时 ${_formatHours(workHours)} 小时',
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('hikiot_token');
      final personNo = prefs.getString('personNo');

      if (token == null || personNo == null) {
        return {'data': null, 'tokenExpired': token == null};
      }

      // 构建今日日期
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final url =
          'https://api.hikiot.com/api-attendance/v1/statistics/individual/single/daily?date=$date&personNo=$personNo&ID=myStatic';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36',
              'Accept': 'application/json, text/plain, */*',
              'Authorization': 'Bearer $token',
              'token': token,
              'www_token': token,
              'Origin': 'https://www.hikiot.com',
              'Referer': 'https://www.hikiot.com/',
              'authPerm': 'MYSTATISTICSFUN',
              'deviceid': 'unHotjaMGfLZCj0N',
              'devicename': 'Android 10',
              'terminal': '2',
              'STN-PhoneType': 'Android 10',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 0) {
          return {'data': data['data'], 'tokenExpired': false};
        } else if (data['code'] == 999999) {
          // Token失效
          return {'data': null, 'tokenExpired': true};
        }
      }
      return {'data': null, 'tokenExpired': false};
    } catch (e) {
      return {'data': null, 'tokenExpired': false};
    }
  }

  /// 获取上班打卡时间 - 使用 AttendanceParser 统一解析
  static String? _getCheckInTime(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return null;

    final parsed = AttendanceParser.parse(dailyDetail);
    if (parsed.checkIn != null && parsed.checkIn!.isNotEmpty && parsed.checkIn != '-') {
      return parsed.checkIn;
    }
    return null;
  }

  /// 获取下班打卡时间 - 使用 AttendanceParser 统一解析
  static String? _getCheckOutTime(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return null;

    final parsed = AttendanceParser.parse(dailyDetail);
    if (parsed.checkOut != null && parsed.checkOut!.isNotEmpty && parsed.checkOut != '-') {
      return parsed.checkOut;
    }
    return null;
  }

  /// 判断是否有上班打卡 - 使用 AttendanceParser 统一解析
  static bool _hasCheckIn(Map<String, dynamic> attendance) {
    return _getCheckInTime(attendance) != null;
  }

  /// 判断是否有下班打卡 - 使用 AttendanceParser 统一解析
  static bool _hasCheckOut(Map<String, dynamic> attendance) {
    return _getCheckOutTime(attendance) != null;
  }

  /// 获取工时 - 使用 AttendanceParser 统一解析
  static double _getWorkHours(Map<String, dynamic> attendance) {
    final dailyDetail = attendance['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return 0;

    // 使用统一的解析器
    final parsed = AttendanceParser.parse(dailyDetail);
    return parsed.hours;
  }

  /// 格式化工时 - 保留两位小数，截断不四舍五入
  static String _formatHours(double hours) {
    // 截断到两位小数
    final truncated = (hours * 100).floor() / 100;
    return truncated.toStringAsFixed(2);
  }

  /// 检查是否为休息日（不需要提醒）
  /// 休息日包括：法定节假日、普通周末（非调休）
  static Future<bool> _isLegalHoliday() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 检查是否在节假日计划中 (使用正确的存储键 'holiday_plan')
    try {
      final prefs = await SharedPreferences.getInstance();
      final holidayPlanJson = prefs.getString('holiday_plan');
      if (holidayPlanJson != null) {
        final allPlans = json.decode(holidayPlanJson) as Map<String, dynamic>;
        final yearPlan = allPlans[now.year.toString()] as Map<String, dynamic>?;

        if (yearPlan != null && yearPlan.containsKey(dateStr)) {
          final dayType = yearPlan[dateStr] as String;
          // 非工作日 = 不需要提醒
          // 工作日（调休）= 需要提醒
          if (dayType == AppConstants.typeRestDay) {
            return true; // 休息日，不提醒
          } else if (dayType == AppConstants.typeWorkday) {
            return false; // 调休工作日，需要提醒
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
      print('解析节假日数据失败: $e');
    }

    // 如果没有节假日数据，根据周末判断
    final weekday = now.weekday; // 1=周一, 7=周日
    if (weekday == 6 || weekday == 7) {
      // 普通周末（没有调休标记），不需要提醒
      return true;
    }

    // 工作日，需要提醒
    return false;
  }
}
