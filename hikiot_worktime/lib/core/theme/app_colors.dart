import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 应用颜色常量
/// 统一管理所有颜色定义，避免硬编码
class AppColors {
  AppColors._();

  // ============ 主题色 ============
  /// 主色调 - 蓝色
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color onPrimary = Colors.white;

  /// 强调色 - 青色
  static const Color accent = Color(0xFF00BCD4);

  // ============ 语义色 - 状态指示 ============
  /// 成功 - 绿色
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF388E3C);

  /// 警告 - 橙色
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color warningDark = Color(0xFFF57C00);

  /// 错误 - 红色
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFFD32F2F);

  /// 信息 - 蓝色
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF1976D2);

  // ============ 工作日类型颜色 ============
  /// 工作日 - 蓝色
  static const Color workday = Color(0xFF2196F3);

  /// 加班日 - 橙色
  static const Color overtime = Color(0xFFFF9800);

  /// 出差 - 紫色
  static const Color businessTrip = Color(0xFF9C27B0);

  /// 请假 - 灰色
  static const Color leave = Color(0xFF9E9E9E);

  /// 非工作日/休息日 - 浅灰
  static const Color restDay = Color(0xFFBDBDBD);

  /// 自定义 - 青色
  static const Color custom = Color(0xFF00BCD4);

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
  static const Color targetCompleted = Color(0xFF4CAF50);

  /// 目标接近 - 蓝色
  static const Color targetNear = Color(0xFF2196F3);

  /// 目标未完成 - 灰色
  static const Color targetPending = Color(0xFF9E9E9E);

  // ============ 日历颜色 ============
  /// 今天高亮
  static const Color todayHighlight = Color(0xFF2196F3);

  /// 周末颜色
  static const Color weekend = Color(0xFFE57373);

  /// 节假日颜色
  static const Color holiday = Color(0xFFEF5350);

  /// 已过日期
  static const Color pastDay = Color(0xFFBDBDBD);

  /// 未来日期
  static const Color futureDay = Color(0xFF90CAF9);

  // ============ 文本颜色 ============
  /// 主要文本
  static const Color textPrimary = Color(0xFF212121);

  /// 次要文本
  static const Color textSecondary = Color(0xFF757575);

  /// 提示文本
  static const Color textHint = Color(0xFF9E9E9E);

  /// 禁用文本
  static const Color textDisabled = Color(0xFFBDBDBD);

  /// 白色文本
  static const Color textWhite = Colors.white;

  // ============ 背景颜色 ============
  /// 页面背景
  static const Color background = Color(0xFFF5F5F5);

  /// 卡片背景
  static const Color cardBackground = Colors.white;

  /// 表面颜色（同卡片背景）
  static const Color surface = Colors.white;

  /// 对话框背景
  static const Color dialogBackground = Colors.white;

  /// 遮罩层
  static const Color overlay = Color(0x80000000);

  /// 进度条背景
  static const Color progressBackground = Color(0xFFE0E0E0);

  // ============ 边框颜色 ============
  /// 默认边框
  static const Color border = Color(0xFFE0E0E0);

  /// 分割线
  static const Color divider = Color(0xFFEEEEEE);

  // ============ 链接颜色 ============
  /// 链接文字
  static const Color link = Color(0xFF1976D2);

  // ============ 第三方文本颜色 ============
  /// 第三方文本
  static const Color textTertiary = Color(0xFFBDBDBD);

  // ============ 其他 ============
  /// 图片预览背景
  static const Color photoPreviewBackground = Colors.black;

  /// 阴影颜色
  static const Color shadow = Color(0x1A000000);

  /// 涟漪效果
  static const Color ripple = Color(0x20000000);
}
