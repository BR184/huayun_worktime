import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

/// 应用样式常量
/// 统一管理文字样式、装饰样式、阴影等
class AppStyles {
  AppStyles._();

  // ============ 阴影 ============
  /// 小阴影
  static List<BoxShadow> get shadowSm => [
    const BoxShadow(
      color: AppColors.highlight,
      blurRadius: 2,
      offset: Offset(-1, -1),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.55),
      blurRadius: 8,
      offset: const Offset(2, 3),
    ),
  ];

  /// 中等阴影
  static List<BoxShadow> get shadowMd => [
    const BoxShadow(
      color: AppColors.highlight,
      blurRadius: 3,
      offset: Offset(-2, -2),
    ),
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.7),
      blurRadius: 14,
      offset: const Offset(3, 5),
    ),
  ];

  /// 大阴影
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // ============ 卡片装饰 ============
  /// 标准卡片装饰
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.surfaceRaised,
    borderRadius: AppDimens.borderRadius,
    border: Border.all(color: AppColors.border),
    boxShadow: shadowSm,
  );

  /// 带边框的卡片装饰
  static BoxDecoration get cardBorderedDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimens.borderRadius,
    border: Border.all(color: AppColors.border),
  );

  /// 带主题色边框的卡片装饰
  static BoxDecoration get cardPrimaryDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimens.borderRadius,
    border: Border.all(color: AppColors.primary),
  );

  // ============ 输入框装饰 ============
  /// 标准输入框装饰
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(borderRadius: AppDimens.borderRadiusMd),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppDimens.borderRadiusMd,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppDimens.borderRadiusMd,
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppDimens.borderRadiusMd,
      borderSide: BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimens.spacing,
      vertical: AppDimens.spacingMd,
    ),
  );

  // ============ 按钮样式 ============
  /// 主要按钮样式
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
    shape: RoundedRectangleBorder(borderRadius: AppDimens.borderRadiusMd),
    elevation: 0,
  );

  /// 次要按钮样式
  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
    side: BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(borderRadius: AppDimens.borderRadiusMd),
  );

  /// 文字按钮样式
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(0, AppDimens.buttonHeightSm),
    shape: RoundedRectangleBorder(borderRadius: AppDimens.borderRadiusMd),
  );

  // ============ 文字样式 ============
  /// 大标题
  static TextStyle get headline => TextStyle(
    fontSize: AppDimens.fontHeadline,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 标题
  static TextStyle get title => TextStyle(
    fontSize: AppDimens.fontTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 副标题
  static TextStyle get subtitle => TextStyle(
    fontSize: AppDimens.fontLg,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 正文
  static TextStyle get body =>
      TextStyle(fontSize: AppDimens.font, color: AppColors.textPrimary);

  /// 正文（次要）
  static TextStyle get bodySecondary =>
      TextStyle(fontSize: AppDimens.font, color: AppColors.textSecondary);

  /// 小字
  static TextStyle get caption =>
      TextStyle(fontSize: AppDimens.fontSm, color: AppColors.textSecondary);

  /// 超小字
  static TextStyle get overline =>
      TextStyle(fontSize: AppDimens.fontXs, color: AppColors.textTertiary);

  /// 链接文字
  static TextStyle get link => TextStyle(
    fontSize: AppDimens.font,
    color: AppColors.link,
    decoration: TextDecoration.underline,
  );

  // ============ 进度条装饰 ============
  /// 进度条背景装饰
  static BoxDecoration get progressBackground => BoxDecoration(
    color: AppColors.progressBackground,
    borderRadius: BorderRadius.circular(AppDimens.progressRadius),
  );

  /// 进度条前景装饰
  static BoxDecoration progressForeground(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(AppDimens.progressRadius),
  );

  // ============ 分隔线 ============
  /// 水平分隔线
  static Widget get divider =>
      Divider(height: 1, thickness: 1, color: AppColors.divider);

  /// 垂直分隔线
  static Widget verticalDivider({double? height}) => Container(
    width: 1,
    height: height ?? AppDimens.spacing,
    color: AppColors.divider,
  );

  // ============ 空状态 ============
  /// 空状态图标样式
  static BoxDecoration get emptyStateIcon =>
      BoxDecoration(color: AppColors.background, shape: BoxShape.circle);

  // ============ 徽章/标签 ============
  /// 创建标签装饰
  static BoxDecoration tagDecoration(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.15),
    borderRadius: AppDimens.borderRadiusSm,
  );

  /// 创建标签文字样式
  static TextStyle tagTextStyle(Color color) => TextStyle(
    fontSize: AppDimens.fontSm,
    fontWeight: FontWeight.w500,
    color: color,
  );
}
