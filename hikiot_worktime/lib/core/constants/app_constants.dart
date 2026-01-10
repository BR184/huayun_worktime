/// 应用常量
/// 统一管理业务相关的常量配置
class AppConstants {
  AppConstants._();

  // ============ 应用信息 ============
  /// 应用名称
  static const String appName = '华云工时查询工具';

  /// 应用版本
  static const String appVersion = '2.0.0';

  // ============ 工时计算 ============
  /// 标准工作时长（小时）
  static const double standardWorkHours = 8.0;

  /// 默认午休时长（分钟）
  static const int defaultLunchDurationMinutes = 60;

  /// 默认午休开始时间
  static const String defaultLunchStart = '12:00';

  /// 默认午休结束时间
  static const String defaultLunchEnd = '13:00';

  /// 默认跨天时间点（分钟，04:00 = 240）
  static const int defaultCrossDayMinutes = 4 * 60;

  // ============ 目标设置 ============
  /// 默认基础目标百分比
  static const int defaultBaseTarget = 120;

  /// 最小目标百分比
  static const int minTargetPercent = 100;

  /// 最大目标百分比
  static const int maxTargetPercent = 300;

  /// 目标档位步长
  static const int targetStep = 10;

  /// 标准目标列表
  static const List<int> standardTargets = [100, 110, 120, 130, 140, 150, 160];

  // ============ 日期类型 ============
  /// 工作日
  static const String typeWorkday = '工作日';

  /// 加班日
  static const String typeOvertime = '加班日';

  /// 出差
  static const String typeBusinessTrip = '出差';

  /// 请假
  static const String typeLeave = '请假';

  /// 休息日/非工作日
  static const String typeRestDay = '非工作日';

  /// 自定义
  static const String typeCustom = '自定义';

  /// 所有工作类型
  static const List<String> allWorkTypes = [
    typeWorkday,
    typeOvertime,
    typeBusinessTrip,
    typeLeave,
    typeRestDay,
    typeCustom,
  ];

  // ============ 出差固定工时 ============
  /// 出差固定工时（小时）
  static const double businessTripHours = 8.0;

  // ============ 状态码 ============
  /// 打卡状态 - 迟到
  static const int clockStatusLate = 1;

  /// 打卡状态 - 早退
  static const int clockStatusEarlyLeave = 4;

  // ============ API响应码 ============
  /// 成功
  static const int apiCodeSuccess = 0;

  /// Token过期
  static const int apiCodeTokenExpired = 999999;

  // ============ 动画时长 ============
  /// 快速动画（毫秒）
  static const int animationFast = 150;

  /// 普通动画（毫秒）
  static const int animationNormal = 300;

  /// 慢速动画（毫秒）
  static const int animationSlow = 500;
}
