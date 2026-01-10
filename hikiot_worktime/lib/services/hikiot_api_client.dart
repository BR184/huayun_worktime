import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/attendance_parser.dart';

/// 海康互联API客户端
class HikiotApiClient {
  // API地址
  static const String baseUrl = 'https://api.hikiot.com';
  static const String accountDetailUrl = '$baseUrl/api-saas/v1/account/detail';
  // V2 API 包含打卡照片信息
  static const String dailyAttendanceUrl =
      '$baseUrl/api-attendance/v1/statistics/v2/individual/single/daily';

  String? _token;

  HikiotApiClient({String? token}) : _token = token;

  /// 设置Token
  void setToken(String token) {
    _token = token;
  }

  /// 获取请求头（移动端格式，支持V2 API照片字段）
  Map<String, String> _getHeaders({bool useBearer = false}) {
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Content-Type': 'application/json',
      'appNo': '__UNI__89A1A02',
      'terminal': '1', // 移动端标识
      'versionCode': '1778',
    };

    if (_token != null) {
      if (useBearer) {
        headers['Authorization'] = 'Bearer $_token';
      }
      headers['token'] = _token!;
      headers['www_token'] = _token!;
    }

    return headers;
  }

  /// 获取账户详情
  Future<Map<String, dynamic>?> getAccountDetail() async {
    try {
      final response = await http.get(
        Uri.parse(accountDetailUrl),
        headers: _getHeaders(useBearer: true),
      );

      print('账户详情API响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('账户详情API响应: $data');

        if (data['code'] == 0) {
          print('账户详情data字段: ${data['data']}');
          return data['data'];
        } else if (data['code'] == 999999) {
          print('登录状态已失效');
          return null;
        } else {
          print('API返回错误码: ${data['code']}, 消息: ${data['msg']}');
          return null;
        }
      }
      print('HTTP请求失败，状态码: ${response.statusCode}');
      return null;
    } catch (e) {
      print('获取账户详情失败: $e');
      return null;
    }
  }

  /// 切换团队上下文（激活Token）
  /// 登录后必须调用此方法，Token才能生效
  Future<bool> changeTeam(String teamNo) async {
    try {
      const changeUrl = 'https://api.hikiot.com/api-link-saas/v3/team/change';

      final response = await http.post(
        Uri.parse(changeUrl),
        headers: _getHeaders(useBearer: true),
        body: json.encode({'teamNo': teamNo, 'terminal': 2}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 0) {
          print('团队切换成功: $teamNo');
          return true;
        } else {
          print('团队切换失败: ${data['msg']}');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('团队切换异常: $e');
      return false;
    }
  }

  /// 退出登录
  Future<bool> logout() async {
    try {
      const logoutUrl = 'https://api.hikiot.com/api-website/v1/logout';

      final response = await http.post(
        Uri.parse(logoutUrl),
        headers: _getHeaders(useBearer: true),
      );

      print('退出登录API响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('退出登录响应: $data');
        return data['code'] == 0;
      }
      return false;
    } catch (e) {
      print('退出登录异常: $e');
      return false;
    }
  }

  /// 获取每日考勤数据 (V2 API，包含照片信息)
  /// [date] 格式: yyyy-MM-dd
  /// [personNo] 保留参数以兼容旧代码，V2 API通过Token识别用户
  Future<Map<String, dynamic>?> getDailyAttendance(
    String date,
    String personNo,
  ) async {
    try {
      // V2 API 不需要personNo，通过Token自动识别
      final url = '$dailyAttendanceUrl?date=$date&ID=myStatic';
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(useBearer: true),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['code'] == 0) {
          return data['data'];
        } else if (data['code'] == 999999) {
          print('登录状态已失效');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('获取每日考勤失败: $e');
      return null;
    }
  }

  /// 获取每月考勤统计(客户端聚合)
  /// [month] 格式: yyyy-MM
  /// [personNo] 员工编号
  Future<Map<String, dynamic>?> getMonthlyAttendance(
    String month,
    String personNo,
  ) async {
    try {
      // 解析年月
      final parts = month.split('-');
      if (parts.length != 2) return null;

      final year = int.parse(parts[0]);
      final monthNum = int.parse(parts[1]);

      // 计算该月的天数
      final lastDay = DateTime(year, monthNum + 1, 0).day;

      // 统计数据
      int workDays = 0;
      double totalHours = 0.0;
      int lateCount = 0;
      final List<Map<String, dynamic>> dailyRecords = [];
      String? personName; // 用户姓名

      // 逐日获取考勤数据
      for (int day = 1; day <= lastDay; day++) {
        final date = DateTime(year, monthNum, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final dailyData = await getDailyAttendance(dateStr, personNo);
        if (dailyData == null) continue;

        // 第一次获取时提取用户姓名
        if (personName == null) {
          personName = dailyData['personName'] as String?;
        }

        // 提取dailyDetail并使用统一解析器
        final dailyDetail = dailyData['dailyDetail'] as Map<String, dynamic>?;
        if (dailyDetail == null) continue;

        final attendance = AttendanceParser.parse(dailyDetail);

        if (attendance.hasValidData) {
          workDays++;

          // 累加工时
          totalHours += attendance.hours;

          // 统计迟到
          if (attendance.isLate) lateCount++;

          dailyRecords.add({
            'date': dateStr,
            'checkIn': attendance.checkIn,
            'checkOut': attendance.checkOut,
            'hours': attendance.hours,
            'isLate': attendance.isLate,
            'isEarlyLeave': attendance.isEarlyLeave,
          });
        }
      }

      // 计算平均工时
      final avgHours = workDays > 0 ? totalHours / workDays : 0.0;

      return {
        'workDays': workDays,
        'totalHours': totalHours,
        'avgHours': avgHours,
        'lateCount': lateCount,
        'dailyRecords': dailyRecords,
        'personName': personName, // 返回用户姓名
      };
    } catch (e) {
      print('获取月度统计失败: $e');
      return null;
    }
  }

  /// 从SharedPreferences加载Token
  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hikiot_token');
  }

  /// 保存Token到SharedPreferences
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hikiot_token', token);
  }
}
