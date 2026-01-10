import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/constants.dart';

/// 本地数据存储服务
class StorageService {
  // 使用StorageKeys常量替代硬编码字符串

  /// 保存基础目标百分比 (默认120%)
  Future<void> saveBaseTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.baseTarget, target);
  }

  /// 加载基础目标百分比 (默认120%)
  Future<int> loadBaseTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.baseTarget) ?? AppConstants.defaultBaseTarget;
  }

  /// 保存智能排序开关
  Future<void> saveSmartSort(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.smartSort, enabled);
  }

  /// 加载智能排序开关 (默认为true)
  Future<bool> loadSmartSort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.smartSort) ?? true;
  }

  /// 保存置顶的目标
  Future<void> savePinnedTarget(int? target) async {
    final prefs = await SharedPreferences.getInstance();
    if (target == null) {
      await prefs.remove(StorageKeys.pinnedTarget);
    } else {
      await prefs.setInt(StorageKeys.pinnedTarget, target);
    }
  }

  /// 加载置顶的目标
  Future<int?> loadPinnedTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.pinnedTarget);
  }

  /// 保存Token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, token);
  }

  /// 加载Token
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.token);
  }

  /// 保存用户名
  Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.userName, userName);
  }

  /// 加载用户名
  Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.userName);
  }

  /// 清除所有数据（退出登录时使用）
  /// 清除认证信息 (保留设置、手动标记和教程状态)
  Future<void> clearAuthInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.userName);
    // 注意：不要清除日历标记、设置、节假日计划等
  }

  /// 保存选择的团队
  Future<void> saveSelectedTeam(String teamNo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.selectedTeam, teamNo);
  }

  /// 加载选择的团队
  Future<String?> loadSelectedTeam() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.selectedTeam);
  }

  /// 保存日历标记（按团队区分）
  Future<void> saveCalendarMarks(
    String teamNo,
    Map<String, Map<String, dynamic>> marks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.calendarMarksKey(teamNo);
    final jsonStr = jsonEncode(marks);
    await prefs.setString(key, jsonStr);
  }

  /// 保存单个日历标记
  Future<void> saveSingleCalendarMark(
    String teamNo,
    String dateStr,
    Map<String, dynamic> markData,
  ) async {
    final marks = await loadCalendarMarks(teamNo);
    marks[dateStr] = markData;
    await saveCalendarMarks(teamNo, marks);
  }

  /// 加载日历标记（按团队区分）
  Future<Map<String, Map<String, dynamic>>> loadCalendarMarks(
    String teamNo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.calendarMarksKey(teamNo);
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (e) {
      return {};
    }
  }

  // ========== 月度考勤数据缓存 ==========

  /// 保存月度考勤数据（按团队+月份）
  Future<void> saveMonthlyData(
    String teamNo,
    String monthKey,
    Map<String, Map<String, dynamic>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.monthlyDataKey(teamNo, monthKey);
    final jsonStr = jsonEncode(data);
    await prefs.setString(key, jsonStr);
  }

  /// 加载月度考勤数据（按团队+月份）
  Future<Map<String, Map<String, dynamic>>?> loadMonthlyData(
    String teamNo,
    String monthKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.monthlyDataKey(teamNo, monthKey);
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) {
      return null;
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (e) {
      return null;
    }
  }

  /// 保存节假日计划
  Future<void> saveHolidayPlan(int year, Map<String, String> plan) async {
    final prefs = await SharedPreferences.getInstance();
    final allPlans = await loadAllHolidayPlans();
    allPlans[year.toString()] = plan;
    final jsonStr = jsonEncode(allPlans);
    await prefs.setString(StorageKeys.holidayPlan, jsonStr);
  }

  /// 加载所有年份的节假日计划
  Future<Map<String, Map<String, String>>> loadAllHolidayPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(StorageKeys.holidayPlan);
    if (jsonStr == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map(
        (year, plan) => MapEntry(year, Map<String, String>.from(plan as Map)),
      );
    } catch (e) {
      return {};
    }
  }

  /// 获取某一年的节假日计划
  Future<Map<String, String>> getHolidayPlan(int year) async {
    final allPlans = await loadAllHolidayPlans();
    return allPlans[year.toString()] ?? {};
  }

  /// 更新节假日 (从API获取)
  Future<bool> updateHolidaysFromAPI(int year) async {
    try {
      final url = 'https://timor.tech/api/holiday/year/$year';
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['code'] == 0) {
          final Map<String, String> plan = {};
          final holiday = data['holiday'] as Map<String, dynamic>;

          // 解析节假日数据 (API键格式是 MM-DD，需要转换为 YYYY-MM-DD)
          holiday.forEach((mmdd, info) {
            final isHoliday = info['holiday'] as bool;
            // 将 MM-DD 转换为 YYYY-MM-DD
            final fullDate = '$year-$mmdd';

            if (isHoliday) {
              // 法定节假日
              plan[fullDate] = AppConstants.typeRestDay;
            } else {
              // 调休工作日
              plan[fullDate] = AppConstants.typeWorkday;
            }
          });

          await saveHolidayPlan(year, plan);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 生成默认节假日计划 (周一至周五工作日)
  Map<String, String> generateDefaultPlan(int year, int month) {
    final Map<String, String> plan = {};
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final weekday = date.weekday; // 1=周一, 7=周日

      String type;
      if (weekday >= 1 && weekday <= 5) {
        type = AppConstants.typeWorkday;
      } else {
        type = AppConstants.typeRestDay;
      }

      final dateStr =
          '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
      plan[dateStr] = type;
    }

    return plan;
  }

  /// 获取某天的默认类型 (从节假日计划或默认规则)
  Future<String> getDayType(String dateStr) async {
    final date = DateTime.parse(dateStr);
    final year = date.year;

    // 先尝试从已保存的计划获取
    final plan = await getHolidayPlan(year);
    if (plan.containsKey(dateStr)) {
      return plan[dateStr]!;
    }

    // 否则按周一至周五规则
    final weekday = date.weekday;
    return (weekday >= 1 && weekday <= 5) ? AppConstants.typeWorkday : AppConstants.typeRestDay;
  }

  /// 保存设置
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings);
    await prefs.setString(StorageKeys.settings, jsonStr);
  }

  /// 加载设置
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(StorageKeys.settings);
    if (jsonStr == null) {
      // 返回默认设置
      return {
        'targets': AppConstants.standardTargets,
        'lunch_break': {'start': AppConstants.defaultLunchStart, 'end': AppConstants.defaultLunchEnd},
        'day_change_hour': AppConstants.defaultCrossDayMinutes ~/ 60,
        'display_name': '',
      };
    }

    try {
      return Map<String, dynamic>.from(jsonDecode(jsonStr));
    } catch (e) {
      return {
        'targets': [100, 120, 130, 140, 150, 160],
        'lunch_break': {'start': '12:00', 'end': '13:00'},
        'day_change_hour': 4,
        'display_name': '',
      };
    }
  }
}
