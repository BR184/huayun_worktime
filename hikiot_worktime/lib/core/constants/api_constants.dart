/// API相关常量
/// 统一管理所有API端点和请求配置
class ApiConstants {
  ApiConstants._();

  // ============ 基础配置 ============
  /// API基础地址
  static const String baseUrl = 'https://api.hikiot.com';

  /// 网站基础地址
  static const String websiteUrl = 'https://www.hikiot.com';

  // ============ 认证相关 ============
  /// 登录页面URL
  static const String loginPageUrl = '$websiteUrl/portal/login';

  /// 退出登录API
  static const String logoutUrl = '$baseUrl/api-website/v1/logout';

  /// 账户详情API
  static const String accountDetailUrl = '$baseUrl/api-saas/v1/account/detail';

  /// 切换团队API
  static const String changeTeamUrl = '$baseUrl/api-link-saas/v3/team/change';

  // ============ 考勤相关 ============
  /// 每日考勤API (V2版本，包含照片信息)
  static const String dailyAttendanceUrl =
      '$baseUrl/api-attendance/v1/statistics/v2/individual/single/daily';

  /// 月度考勤API
  static const String monthlyAttendanceUrl =
      '$baseUrl/api-attendance/v1/statistics/myAttendance';

  /// 请假记录API
  static const String leaveRecordUrl =
      '$baseUrl/api-attendance/leaveRecord/getTodayRecords';

  // ============ 请求头配置 ============
  /// 移动端User-Agent
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36';

  /// 应用编号
  static const String appNo = '__UNI__89A1A02';

  /// 移动端终端标识
  static const String terminalMobile = '1';

  /// Web端终端标识
  static const String terminalWeb = '2';

  /// 版本号
  static const String versionCode = '1778';

  // ============ 超时配置 ============
  /// 连接超时时间（秒）
  static const int connectTimeoutSeconds = 30;

  /// 读取超时时间（秒）
  static const int readTimeoutSeconds = 30;
}
