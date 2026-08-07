import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 应用颜色常量
/// 统一管理所有颜色定义，避免硬编码
class AppColors {
  AppColors._();

  // ============ 主题色 ============
  /// 主色调 - 活力钴蓝
  static const Color primary = Color(0xFF4057E8);
  static const Color primaryLight = Color(0xFFDDE4FF);
  static const Color primaryDark = Color(0xFF18245D);
  static const Color onPrimary = Colors.white;

  /// 辅色 - 青柚绿，用于完成与正常状态
  static const Color secondary = Color(0xFF008F7A);
  static const Color secondaryLight = Color(0xFFB9F2E5);
  static const Color secondaryDark = Color(0xFF00382F);

  /// 第三色 - 莓红，用于特殊提醒与手动修正
  static const Color tertiary = Color(0xFFC23B63);
  static const Color tertiaryLight = Color(0xFFFFD9E1);
  static const Color tertiaryDark = Color(0xFF5A1025);

  /// 强调色兼容别名，业务状态统一使用 secondary/tertiary
  static const Color accent = tertiary;

  // ============ 语义色 - 状态指示 ============
  /// 成功 - 绿色
  static const Color success = secondary;
  static const Color successLight = secondaryLight;
  static const Color successDark = secondaryDark;

  /// 警告 - 橙色
  static const Color warning = Color(0xFFA66300);
  static const Color warningLight = Color(0xFFFFF0C2);
  static const Color warningDark = Color(0xFF5A3A00);

  /// 错误 - 红色
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorLight = Color(0xFFFFDAD6);
  static const Color errorDark = Color(0xFF93000A);

  /// 信息 - 蓝色
  static const Color info = primary;
  static const Color infoLight = primaryLight;
  static const Color infoDark = primaryDark;

  // ============ 工作日类型颜色 ============
  /// 工作日 - 蓝色
  static const Color workday = primary;

  /// 加班日 - 橙色
  static const Color overtime = tertiary;

  /// 出差 - 紫色
  static const Color businessTrip = tertiary;

  /// 请假 - 灰色
  static const Color leave = errorDark;

  /// 非工作日/休息日 - 浅灰
  static const Color restDay = Color(0xFF77817D);

  /// 自定义 - 青色
  static const Color custom = secondary;

  /// 根据工作类型获取颜色
  static Color getTypeColor(String type) {
    switch (type) {
      case AppConstants.typeWorkday:
        return workday;
      case AppConstants.typeOvertime:
        return overtime;
      case AppConstants.typeBusinessTrip:
        return businessTrip;
      case AppConstants.typeLeave:
        return leave;
      case AppConstants.typeRestDay:
        return restDay;
      case AppConstants.typeCustom:
        return custom;
      default:
        return workday;
    }
  }

  // ============ 目标进度颜色 ============
  /// 目标完成 - 绿色
  static const Color targetCompleted = success;

  /// 目标接近 - 蓝色
  static const Color targetNear = primary;

  /// 目标未完成 - 灰色
  static const Color targetPending = Color(0xFF9E9E9E);

  // ============ 日历颜色 ============
  /// 今天高亮
  static const Color todayHighlight = tertiary;

  /// 周末颜色
  static const Color weekend = tertiary;

  /// 节假日颜色
  static const Color holiday = error;

  /// 已过日期
  static const Color pastDay = Color(0xFFBDBDBD);

  /// 未来日期
  static const Color futureDay = primaryLight;

  // ============ 文本颜色 ============
  /// 主要文本
  static const Color textPrimary = Color(0xFF17201E);

  /// 次要文本
  static const Color textSecondary = Color(0xFF59635F);

  /// 提示文本
  static const Color textHint = Color(0xFF7B8581);

  /// 禁用文本
  static const Color textDisabled = Color(0xFFA8B1AD);

  /// 两位小数中的百分位，仅供查看、不计入统计
  static const Color decimalMuted = Color(0xFF9AA6A1);

  /// 白色文本
  static const Color textWhite = Colors.white;

  // ============ 背景颜色 ============
  /// 页面背景
  static const Color background = Color(0xFFF7F8FC);

  /// 卡片背景
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// 表面颜色（同卡片背景）
  static const Color surface = Color(0xFFFFFFFF);

  /// 抬升表面
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// 下沉表面
  static const Color surfaceSunken = Color(0xFFEEF1F7);

  /// 对话框背景
  static const Color dialogBackground = Colors.white;

  /// 遮罩层
  static const Color overlay = Color(0x80000000);

  /// 进度条背景
  static const Color progressBackground = Color(0xFFE1E4EC);

  // ============ 边框颜色 ============
  /// 默认边框
  static const Color border = Color(0xFFDCE1EC);

  /// 分割线
  static const Color divider = Color(0xFFE6E9F0);

  // ============ 链接颜色 ============
  /// 链接文字
  static const Color link = primaryDark;

  // ============ 第三方文本颜色 ============
  /// 第三方文本
  static const Color textTertiary = Color(0xFF87918D);

  // ============ 其他 ============
  /// 图片预览背景
  static const Color photoPreviewBackground = Colors.black;

  /// 阴影颜色
  static const Color shadow = Color(0x1F24322D);

  /// 轻拟物上缘高光
  static const Color highlight = Color(0xD9FFFFFF);

  /// 涟漪效果
  static const Color ripple = Color(0x20000000);
}
