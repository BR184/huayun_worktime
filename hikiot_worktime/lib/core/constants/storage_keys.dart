/// 本地存储Key常量
/// 统一管理SharedPreferences中的所有key，避免魔法字符串
class StorageKeys {
  StorageKeys._();

  // ============ 认证相关 ============
  /// 用户Token
  static const String token = 'hikiot_token';

  /// 用户名
  static const String userName = 'user_name';

  /// 员工编号
  static const String personNo = 'personNo';

  /// 团队编号
  static const String teamNo = 'teamNo';

  /// 选中的团队
  static const String selectedTeam = 'selected_team';

  // ============ 设置相关 ============
  /// 通用设置
  static const String settings = 'settings';

  /// 午休开始时间
  static const String lunchStartTime = 'lunch_start_time';

  /// 午休结束时间
  static const String lunchEndTime = 'lunch_end_time';

  /// 跨天时间点（分钟）
  static const String crossDayMinutes = 'cross_day_minutes';

  /// 基础目标百分比
  static const String baseTarget = 'base_target';

  /// 置顶目标
  static const String pinnedTarget = 'pinned_target';

  /// 智能排序开关
  static const String smartSort = 'smart_sort';

  // ============ 震动设置 ============
  /// 震动模式
  static const String hapticMode = 'haptic_mode';

  // ============ 数据缓存 ============
  /// 日历标记前缀 (实际key: calendar_marks_{teamNo})
  static const String calendarMarksPrefix = 'calendar_marks';

  /// 月度数据前缀 (实际key: monthly_data_{teamNo}_{month})
  static const String monthlyDataPrefix = 'monthly_data';

  /// 节假日计划
  static const String holidayPlan = 'holiday_plan';

  // ============ 提醒相关 ============
  /// 上班提醒开关
  static const String morningReminderEnabled = 'morning_reminder_enabled';

  /// 下班提醒开关
  static const String eveningReminderEnabled = 'evening_reminder_enabled';

  /// 上班提醒时间
  static const String morningReminderTime = 'morning_reminder_time';

  /// 下班提醒时间
  static const String eveningReminderTime = 'evening_reminder_time';

  // ============ 引导相关 ============
  /// 新手引导完成标记
  static const String onboardingCompleted = 'onboarding_completed';

  /// 免责声明确认标记
  static const String disclaimerAccepted = 'disclaimer_accepted';

  /// 首次提醒引导完成标记
  static const String reminderGuideShown = 'reminder_guide_shown';

  // ============ 辅助方法 ============
  /// 获取日历标记的完整key
  static String calendarMarksKey(String teamNo) =>
      '${calendarMarksPrefix}_$teamNo';

  /// 获取月度数据的完整key
  static String monthlyDataKey(String teamNo, String month) =>
      '${monthlyDataPrefix}_${teamNo}_$month';
}
