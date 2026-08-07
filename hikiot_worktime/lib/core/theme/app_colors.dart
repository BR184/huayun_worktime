import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 应用颜色常量
/// 统一管理所有颜色定义，避免硬编码
class AppColors {
  AppColors._();

  // ============ 主题色 ============
  /// 主色调 - 仪表玉绿
  static const Color primary = Color(0xFF3D5A57);
  static const Color primaryLight = Color(0xFFDCE9E5);
  static const Color primaryDark = Color(0xFF29433F);
  static const Color onPrimary = Colors.white;

  /// 强调色 - 精密琥珀
  static const Color accent = Color(0xFFB56B45);

  // ============ 语义色 - 状态指示 ============
  /// 成功 - 绿色
  static const Color success = Color(0xFF4C7A68);
  static const Color successLight = Color(0xFFE4EEE9);
  static const Color successDark = Color(0xFF345D50);

  /// 警告 - 橙色
  static const Color warning = Color(0xFFB56B45);
  static const Color warningLight = Color(0xFFF8E9DF);
  static const Color warningDark = Color(0xFF7F4932);

  /// 错误 - 红色
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFFD32F2F);

  /// 信息 - 蓝色
  static const Color info = Color(0xFF5C7180);
  static const Color infoLight = Color(0xFFE7EDF0);
  static const Color infoDark = Color(0xFF3E5361);

  // ============ 工作日类型颜色 ============
  /// 工作日 - 蓝色
  static const Color workday = primary;

  /// 加班日 - 橙色
  static const Color overtime = Color(0xFF7A6674);

  /// 出差 - 紫色
  static const Color businessTrip = accent;

  /// 请假 - 灰色
  static const Color leave = errorDark;

  /// 非工作日/休息日 - 浅灰
  static const Color restDay = Color(0xFF77817D);

  /// 自定义 - 青色
  static const Color custom = Color(0xFF147D87);

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
  static const Color todayHighlight = Color(0xFFB56B45);

  /// 周末颜色
  static const Color weekend = Color(0xFFC17D72);

  /// 节假日颜色
  static const Color holiday = Color(0xFFC17D72);

  /// 已过日期
  static const Color pastDay = Color(0xFFBDBDBD);

  /// 未来日期
  static const Color futureDay = Color(0xFFB7C9C4);

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
  static const Color background = Color(0xFFF5F3EF);

  /// 卡片背景
  static const Color cardBackground = Color(0xFFFFFEFA);

  /// 表面颜色（同卡片背景）
  static const Color surface = Color(0xFFFFFEFA);

  /// 抬升表面
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// 下沉表面
  static const Color surfaceSunken = Color(0xFFEAEAE4);

  /// 对话框背景
  static const Color dialogBackground = Colors.white;

  /// 遮罩层
  static const Color overlay = Color(0x80000000);

  /// 进度条背景
  static const Color progressBackground = Color(0xFFDDE4E0);

  // ============ 边框颜色 ============
  /// 默认边框
  static const Color border = Color(0xFFDEDCD5);

  /// 分割线
  static const Color divider = Color(0xFFE7E4DD);

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
