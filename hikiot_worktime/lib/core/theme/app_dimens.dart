import 'package:flutter/material.dart';

/// 应用尺寸常量
/// 统一管理间距、圆角、字体大小等
class AppDimens {
  AppDimens._();

  // ============ 间距 ============
  /// 极小间距
  static const double spacingXs = 4.0;

  /// 小间距
  static const double spacingSm = 8.0;

  /// 中等间距
  static const double spacingMd = 12.0;

  /// 标准间距
  static const double spacing = 16.0;

  /// 大间距
  static const double spacingLg = 24.0;

  /// 超大间距
  static const double spacingXl = 32.0;

  // ============ 圆角 ============
  /// 小圆角
  static const double radiusSm = 4.0;

  /// 中等圆角
  static const double radiusMd = 8.0;

  /// 标准圆角
  static const double radius = 8.0;

  /// 大圆角
  static const double radiusLg = 12.0;

  /// 超大圆角
  static const double radiusXl = 16.0;

  /// 圆形
  static const double radiusCircle = 999.0;

  // ============ BorderRadius 快捷方式 ============
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadius => BorderRadius.circular(radius);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  // ============ 字体大小 ============
  /// 超小字体
  static const double fontXs = 10.0;

  /// 小字体
  static const double fontSm = 12.0;

  /// 中等字体
  static const double fontMd = 14.0;

  /// 标准字体
  static const double font = 16.0;

  /// 大字体
  static const double fontLg = 18.0;

  /// 超大字体
  static const double fontXl = 20.0;

  /// 标题字体
  static const double fontTitle = 24.0;

  /// 大标题字体
  static const double fontHeadline = 32.0;

  // ============ 图标大小 ============
  /// 小图标
  static const double iconSm = 16.0;

  /// 中等图标
  static const double iconMd = 20.0;

  /// 标准图标
  static const double icon = 24.0;

  /// 大图标
  static const double iconLg = 32.0;

  /// 超大图标
  static const double iconXl = 48.0;

  // ============ 按钮高度 ============
  /// 小按钮高度
  static const double buttonHeightSm = 32.0;

  /// 标准按钮高度
  static const double buttonHeight = 48.0;

  /// 大按钮高度
  static const double buttonHeightLg = 52.0;

  // ============ 卡片 ============
  /// 卡片高度
  static const double cardElevation = 2.0;

  /// 卡片内边距
  static const EdgeInsets cardPadding = EdgeInsets.all(spacingMd);

  /// 卡片外边距
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: spacing,
    vertical: spacingSm,
  );

  // ============ AppBar ============
  /// AppBar高度
  static const double appBarHeight = 56.0;

  // ============ 底部导航栏 ============
  /// 底部导航栏高度
  static const double bottomNavHeight = 60.0;

  // ============ 对话框 ============
  /// 对话框最大宽度
  static const double dialogMaxWidth = 400.0;

  /// 对话框圆角
  static BorderRadius get dialogRadius => borderRadiusLg;

  // ============ 进度条 ============
  /// 进度条高度
  static const double progressHeight = 8.0;

  /// 进度条圆角
  static const double progressRadius = 4.0;

  // ============ 列表项 ============
  /// 列表项高度
  static const double listItemHeight = 56.0;

  /// 列表项内边距
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: spacing,
    vertical: spacingMd,
  );
}
