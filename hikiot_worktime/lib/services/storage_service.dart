import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/constants.dart';

class ReminderSettings {
  const ReminderSettings({
    required this.morningEnabled,
    required this.morningHour,
    required this.morningMinute,
    required this.eveningEnabled,
    required this.eveningHour,
    required this.eveningMinute,
  });

  final bool morningEnabled;
  final int morningHour;
  final int morningMinute;
  final bool eveningEnabled;
  final int eveningHour;
  final int eveningMinute;

  ReminderSettings copyWith({
    bool? morningEnabled,
    int? morningHour,
    int? morningMinute,
    bool? eveningEnabled,
    int? eveningHour,
    int? eveningMinute,
  }) {
    return ReminderSettings(
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      eveningHour: eveningHour ?? this.eveningHour,
      eveningMinute: eveningMinute ?? this.eveningMinute,
    );
  }
}

/// Local storage facade for SharedPreferences.
class StorageService {
  static const String _legacyDisclaimerAccepted = 'disclaimer_shown';
  static const String _legacyCurrentTeamNo = 'current_team_no';
  static const String _legacyCurrentTeamName = 'current_team_name';
  static const String _legacyCurrentUserName = 'current_user_name';
  static const String _legacyMorningEnabled = 'morning_alarm_enabled';
  static const String _legacyMorningHour = 'morning_alarm_hour';
  static const String _legacyMorningMinute = 'morning_alarm_minute';
  static const String _legacyEveningEnabled = 'evening_alarm_enabled';
  static const String _legacyEveningHour = 'evening_alarm_hour';
  static const String _legacyEveningMinute = 'evening_alarm_minute';

  Future<void> saveBaseTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.baseTarget, target);
  }

  Future<int> loadBaseTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.baseTarget) ??
        AppConstants.defaultBaseTarget;
  }

  Future<void> saveSmartSort(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.smartSort, enabled);
  }

  Future<bool> loadSmartSort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.smartSort) ?? true;
  }

  Future<void> saveExtendedTargetRange(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.extendedTargetRange, enabled);
  }

  Future<bool> loadExtendedTargetRange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.extendedTargetRange) ?? false;
  }

  Future<void> saveDebugToolsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.debugToolsEnabled, enabled);
  }

  Future<bool> loadDebugToolsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.debugToolsEnabled) ?? false;
  }

  Future<void> saveHapticModeIndex(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.hapticMode, modeIndex);
  }

  Future<int> loadHapticModeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.hapticMode) ?? 0;
  }

  Future<void> savePinnedTarget(int? target) async {
    final prefs = await SharedPreferences.getInstance();
    if (target == null) {
      await prefs.remove(StorageKeys.pinnedTarget);
    } else {
      await prefs.setInt(StorageKeys.pinnedTarget, target);
    }
  }

  Future<int?> loadPinnedTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.pinnedTarget);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      await prefs.remove(StorageKeys.token);
      return;
    }
    await prefs.setString(StorageKeys.token, normalizedToken);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.token);
    final normalizedToken = token?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      if (token != null) {
        await prefs.remove(StorageKeys.token);
      }
      return null;
    }
    if (normalizedToken != token) {
      await prefs.setString(StorageKeys.token, normalizedToken);
    }
    return normalizedToken;
  }

  Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.userName, userName);
    await prefs.setString(_legacyCurrentUserName, userName);
  }

  Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userName =
        prefs.getString(StorageKeys.userName) ??
        prefs.getString(_legacyCurrentUserName);
    if (userName != null && userName.isNotEmpty) {
      await prefs.setString(StorageKeys.userName, userName);
      await prefs.setString(_legacyCurrentUserName, userName);
    }
    return userName;
  }

  /// 保存当前团队上下文。
  ///
  /// personNo 属于团队认证上下文，与当前团队强绑定：没有新值时必须清除
  /// 旧值，否则换账号/切团队后会把旧账号的 personNo 当成新账号的。
  Future<void> saveTeamContext({
    required String teamNo,
    String? personNo,
    String? teamName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.teamNo, teamNo);
    await prefs.setString(_legacyCurrentTeamNo, teamNo);
    if (personNo != null && personNo.isNotEmpty) {
      await prefs.setString(StorageKeys.personNo, personNo);
    } else {
      await prefs.remove(StorageKeys.personNo);
    }
    if (teamName != null && teamName.isNotEmpty) {
      await prefs.setString(StorageKeys.teamName, teamName);
      await prefs.setString(_legacyCurrentTeamName, teamName);
    }
  }

  Future<String?> loadTeamNo() async {
    final prefs = await SharedPreferences.getInstance();
    final teamNo =
        prefs.getString(StorageKeys.teamNo) ??
        prefs.getString(_legacyCurrentTeamNo);
    if (teamNo != null && teamNo.isNotEmpty) {
      await prefs.setString(StorageKeys.teamNo, teamNo);
      await prefs.setString(_legacyCurrentTeamNo, teamNo);
    }
    return teamNo;
  }

  Future<String?> loadTeamName() async {
    final prefs = await SharedPreferences.getInstance();
    final teamName =
        prefs.getString(StorageKeys.teamName) ??
        prefs.getString(_legacyCurrentTeamName);
    if (teamName != null && teamName.isNotEmpty) {
      await prefs.setString(StorageKeys.teamName, teamName);
      await prefs.setString(_legacyCurrentTeamName, teamName);
    }
    return teamName;
  }

  Future<String?> loadPersonNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.personNo);
  }

  /// 清理全部认证上下文：token、用户名、团队、人员编号及 legacy key。
  ///
  /// 只清理"当前是谁"相关的键，保留全局用户偏好设置（午休、目标、
  /// 震动模式、提醒开关等）。月度缓存与日历手动标记按 teamNo 分键，
  /// 登出后新账号使用自己的 teamNo 读取，不会串号，因此保留。
  Future<void> clearAuthInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.userName);
    await prefs.remove(_legacyCurrentUserName);
    await prefs.remove(StorageKeys.teamNo);
    await prefs.remove(_legacyCurrentTeamNo);
    await prefs.remove(StorageKeys.teamName);
    await prefs.remove(_legacyCurrentTeamName);
    await prefs.remove(StorageKeys.personNo);
    await prefs.remove(StorageKeys.selectedTeam);
  }

  Future<void> saveOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.onboardingCompleted, completed);
  }

  Future<bool> loadOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
  }

  Future<void> saveDisclaimerAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.disclaimerAccepted, accepted);
    await prefs.setBool(_legacyDisclaimerAccepted, accepted);
  }

  Future<bool> loadDisclaimerAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted =
        prefs.getBool(StorageKeys.disclaimerAccepted) ??
        prefs.getBool(_legacyDisclaimerAccepted) ??
        false;
    await prefs.setBool(StorageKeys.disclaimerAccepted, accepted);
    await prefs.setBool(_legacyDisclaimerAccepted, accepted);
    return accepted;
  }

  Future<void> saveSelectedTeam(String teamNo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.selectedTeam, teamNo);
  }

  Future<String?> loadSelectedTeam() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.selectedTeam);
  }

  Future<void> saveCommuteMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.commuteMode, mode);
  }

  /// 默认自由出行
  Future<String> loadCommuteMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.commuteMode) ?? 'free';
  }

  /// 是否已设置过通勤方式（用于首次进入弹初始化设置）
  Future<bool> hasCommuteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.commuteMode) != null;
  }

  Future<void> saveCommuteMetroDirection(int direction) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.commuteMetroDirection, direction);
  }

  Future<int> loadCommuteMetroDirection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.commuteMetroDirection) ?? 0;
  }

  Future<void> saveCalendarMarks(
    String teamNo,
    Map<String, Map<String, dynamic>> marks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.calendarMarksKey(teamNo);
    await prefs.setString(key, jsonEncode(marks));
  }

  Future<void> saveSingleCalendarMark(
    String teamNo,
    String dateStr,
    Map<String, dynamic> markData,
  ) async {
    final marks = await loadCalendarMarks(teamNo);
    marks[dateStr] = markData;
    await saveCalendarMarks(teamNo, marks);
  }

  Future<Map<String, Map<String, dynamic>>> loadCalendarMarks(
    String teamNo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(StorageKeys.calendarMarksKey(teamNo));
    if (jsonStr == null) return {};

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> saveMonthlyData(
    String teamNo,
    String monthKey,
    Map<String, Map<String, dynamic>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = StorageKeys.monthlyDataKey(teamNo, monthKey);
    await prefs.setString(key, jsonEncode(data));
  }

  Future<Map<String, Map<String, dynamic>>?> loadMonthlyData(
    String teamNo,
    String monthKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(
      StorageKeys.monthlyDataKey(teamNo, monthKey),
    );
    if (jsonStr == null) return null;

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> saveHolidayPlan(int year, Map<String, String> plan) async {
    final prefs = await SharedPreferences.getInstance();
    final allPlans = await loadAllHolidayPlans();
    allPlans[year.toString()] = plan;
    await prefs.setString(StorageKeys.holidayPlan, jsonEncode(allPlans));
  }

  Future<Map<String, Map<String, String>>> loadAllHolidayPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(StorageKeys.holidayPlan);
    if (jsonStr == null) return {};

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return {};
      return decoded.map(
        (year, plan) =>
            MapEntry(year as String, Map<String, String>.from(plan as Map)),
      );
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, String>> getHolidayPlan(int year) async {
    final allPlans = await loadAllHolidayPlans();
    return allPlans[year.toString()] ?? {};
  }

  Map<String, String> generateDefaultPlan(int year, int month) {
    final plan = <String, String>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final type = date.weekday >= 1 && date.weekday <= 5
          ? AppConstants.typeWorkday
          : AppConstants.typeRestDay;
      final dateStr =
          '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
      plan[dateStr] = type;
    }

    return plan;
  }

  Future<String> getDayType(String dateStr) async {
    final date = DateTime.parse(dateStr);
    final plan = await getHolidayPlan(date.year);
    if (plan.containsKey(dateStr)) {
      return plan[dateStr]!;
    }

    return date.weekday >= 1 && date.weekday <= 5
        ? AppConstants.typeWorkday
        : AppConstants.typeRestDay;
  }

  Future<ReminderSettings> loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final morningTime = _readReminderTime(
      prefs.getString(StorageKeys.morningReminderTime),
      legacyHour: prefs.getInt(_legacyMorningHour),
      legacyMinute: prefs.getInt(_legacyMorningMinute),
      defaultHour: 8,
      defaultMinute: 55,
    );
    final eveningTime = _readReminderTime(
      prefs.getString(StorageKeys.eveningReminderTime),
      legacyHour: prefs.getInt(_legacyEveningHour),
      legacyMinute: prefs.getInt(_legacyEveningMinute),
      defaultHour: 21,
      defaultMinute: 0,
    );
    final settings = ReminderSettings(
      morningEnabled:
          prefs.getBool(StorageKeys.morningReminderEnabled) ??
          prefs.getBool(_legacyMorningEnabled) ??
          false,
      morningHour: morningTime.$1,
      morningMinute: morningTime.$2,
      eveningEnabled:
          prefs.getBool(StorageKeys.eveningReminderEnabled) ??
          prefs.getBool(_legacyEveningEnabled) ??
          false,
      eveningHour: eveningTime.$1,
      eveningMinute: eveningTime.$2,
    );
    await _persistReminderSettings(prefs, settings);
    return settings;
  }

  Future<void> saveMorningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final current = await loadReminderSettings();
    final next = current.copyWith(
      morningEnabled: enabled,
      morningHour: hour,
      morningMinute: minute,
    );
    final prefs = await SharedPreferences.getInstance();
    await _persistReminderSettings(prefs, next);
  }

  Future<void> saveEveningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final current = await loadReminderSettings();
    final next = current.copyWith(
      eveningEnabled: enabled,
      eveningHour: hour,
      eveningMinute: minute,
    );
    final prefs = await SharedPreferences.getInstance();
    await _persistReminderSettings(prefs, next);
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeSettings(settings);
    await _persistSettings(prefs, normalized);
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};
    final jsonStr = prefs.getString(StorageKeys.settings);

    try {
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          settings.addAll(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      settings.clear();
    }

    final storedLunchStart = prefs.getString(StorageKeys.lunchStartTime);
    final storedLunchEnd = prefs.getString(StorageKeys.lunchEndTime);
    final storedCrossDay = prefs.getInt(StorageKeys.crossDayMinutes);
    if (storedLunchStart != null) {
      settings[StorageKeys.lunchStartTime] = storedLunchStart;
    }
    if (storedLunchEnd != null) {
      settings[StorageKeys.lunchEndTime] = storedLunchEnd;
    }
    if (storedCrossDay != null) {
      settings[StorageKeys.crossDayMinutes] = storedCrossDay;
    }

    final normalized = _normalizeSettings(settings);
    await _persistSettings(prefs, normalized);
    return normalized;
  }

  Map<String, dynamic> _defaultSettings() {
    return {
      'targets': List<int>.from(AppConstants.standardTargets),
      StorageKeys.lunchStartTime: AppConstants.defaultLunchStart,
      StorageKeys.lunchEndTime: AppConstants.defaultLunchEnd,
      StorageKeys.crossDayMinutes: AppConstants.defaultCrossDayMinutes,
      'lunchStartTime': AppConstants.defaultLunchStart,
      'lunchEndTime': AppConstants.defaultLunchEnd,
      'lunch_break': {
        'start': AppConstants.defaultLunchStart,
        'end': AppConstants.defaultLunchEnd,
      },
      'day_change_hour': AppConstants.defaultCrossDayMinutes ~/ 60,
      'display_name': '',
    };
  }

  Map<String, dynamic> _normalizeSettings(Map<String, dynamic> rawSettings) {
    final normalized = <String, dynamic>{..._defaultSettings(), ...rawSettings};

    final lunchStart =
        _readString(rawSettings, 'lunchStartTime') ??
        _readString(rawSettings, StorageKeys.lunchStartTime) ??
        _readNestedString(rawSettings, 'lunch_break', 'start') ??
        AppConstants.defaultLunchStart;
    final lunchEnd =
        _readString(rawSettings, 'lunchEndTime') ??
        _readString(rawSettings, StorageKeys.lunchEndTime) ??
        _readNestedString(rawSettings, 'lunch_break', 'end') ??
        AppConstants.defaultLunchEnd;
    final legacyCrossDayHour = _readInt(rawSettings, 'day_change_hour');
    final crossDayMinutes =
        _readInt(rawSettings, StorageKeys.crossDayMinutes) ??
        _readInt(rawSettings, 'crossDayMinutes') ??
        (legacyCrossDayHour != null ? legacyCrossDayHour * 60 : null) ??
        AppConstants.defaultCrossDayMinutes;

    normalized[StorageKeys.lunchStartTime] = lunchStart;
    normalized[StorageKeys.lunchEndTime] = lunchEnd;
    normalized[StorageKeys.crossDayMinutes] = crossDayMinutes;
    normalized['lunchStartTime'] = lunchStart;
    normalized['lunchEndTime'] = lunchEnd;
    normalized['lunch_break'] = {'start': lunchStart, 'end': lunchEnd};
    normalized['day_change_hour'] = crossDayMinutes ~/ 60;

    return normalized;
  }

  Future<void> _persistSettings(
    SharedPreferences prefs,
    Map<String, dynamic> settings,
  ) async {
    await prefs.setString(StorageKeys.settings, jsonEncode(settings));
    await prefs.setString(
      StorageKeys.lunchStartTime,
      settings[StorageKeys.lunchStartTime] as String,
    );
    await prefs.setString(
      StorageKeys.lunchEndTime,
      settings[StorageKeys.lunchEndTime] as String,
    );
    await prefs.setInt(
      StorageKeys.crossDayMinutes,
      settings[StorageKeys.crossDayMinutes] as int,
    );
  }

  String? _readString(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? _readNestedString(
    Map<String, dynamic> source,
    String parentKey,
    String childKey,
  ) {
    final parent = source[parentKey];
    if (parent is! Map) return null;
    final value = parent[childKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _readInt(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  (int, int) _readReminderTime(
    String? canonicalTime, {
    required int? legacyHour,
    required int? legacyMinute,
    required int defaultHour,
    required int defaultMinute,
  }) {
    final parsed = _parseReminderTime(canonicalTime);
    if (parsed != null) return parsed;

    final hour = legacyHour ?? defaultHour;
    final minute = legacyMinute ?? defaultMinute;
    if (_isValidReminderTime(hour, minute)) {
      return (hour, minute);
    }

    return (defaultHour, defaultMinute);
  }

  (int, int)? _parseReminderTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return _isValidReminderTime(hour, minute) ? (hour, minute) : null;
  }

  bool _isValidReminderTime(int hour, int minute) {
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  Future<void> _persistReminderSettings(
    SharedPreferences prefs,
    ReminderSettings settings,
  ) async {
    final morningTime = _formatReminderTime(
      settings.morningHour,
      settings.morningMinute,
    );
    final eveningTime = _formatReminderTime(
      settings.eveningHour,
      settings.eveningMinute,
    );

    await prefs.setBool(
      StorageKeys.morningReminderEnabled,
      settings.morningEnabled,
    );
    await prefs.setString(StorageKeys.morningReminderTime, morningTime);
    await prefs.setBool(
      StorageKeys.eveningReminderEnabled,
      settings.eveningEnabled,
    );
    await prefs.setString(StorageKeys.eveningReminderTime, eveningTime);

    await prefs.setBool(_legacyMorningEnabled, settings.morningEnabled);
    await prefs.setInt(_legacyMorningHour, settings.morningHour);
    await prefs.setInt(_legacyMorningMinute, settings.morningMinute);
    await prefs.setBool(_legacyEveningEnabled, settings.eveningEnabled);
    await prefs.setInt(_legacyEveningHour, settings.eveningHour);
    await prefs.setInt(_legacyEveningMinute, settings.eveningMinute);
  }

  String _formatReminderTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
