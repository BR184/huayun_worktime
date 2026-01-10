import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 震动模式枚举
enum HapticMode {
  /// 高级模式 - 适用于线性马达，丰富的震动效果
  advanced,

  /// 基础模式 - 适用于转子马达，简化的震动效果
  basic,

  /// 关闭 - 不震动
  off,
}

/// 震动反馈工具类
class HapticUtils {
  static HapticMode _mode = HapticMode.advanced;
  static const String _prefKey = 'haptic_mode';

  /// 获取当前震动模式
  static HapticMode get mode => _mode;

  /// 初始化震动设置（应用启动时调用）
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_prefKey) ?? 0;
    _mode = HapticMode.values[modeIndex.clamp(0, HapticMode.values.length - 1)];
  }

  /// 设置震动模式
  static Future<void> setMode(HapticMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, mode.index);
  }

  /// 轻触反馈 - 用于普通按钮点击
  static Future<void> lightImpact() async {
    if (_mode == HapticMode.off) return;
    await HapticFeedback.lightImpact();
  }

  /// 中等反馈 - 用于重要操作
  static Future<void> mediumImpact() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      // 基础模式使用 vibrate 代替精细震动
      await HapticFeedback.vibrate();
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  /// 重度反馈 - 用于删除、确认等重要操作
  static Future<void> heavyImpact() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      await HapticFeedback.vibrate();
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  /// 选择反馈 - 用于选择器、下拉选择
  static Future<void> selectionClick() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      // 基础模式跳过细微的选择震动
      return;
    }
    await HapticFeedback.selectionClick();
  }

  /// 震动反馈 - 通用震动
  static Future<void> vibrate() async {
    if (_mode == HapticMode.off) return;
    await HapticFeedback.vibrate();
  }

  /// 模拟 iPhone 8 Home 键按下效果
  static Future<void> homeButtonDown() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      await HapticFeedback.vibrate();
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  /// 模拟 iPhone 8 Home 键释放效果
  static Future<void> homeButtonUp() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      // 基础模式不需要释放震动
      return;
    }
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// 完整的 Home 键按压体验（按下+释放）
  static Future<void> homeButtonPress() async {
    await homeButtonDown();
    await homeButtonUp();
  }

  /// 下拉刷新蓄力震动
  static Future<void> pullRefreshCharging() async {
    if (_mode != HapticMode.advanced) return;
    await HapticFeedback.selectionClick();
  }

  /// 下拉刷新触发点震动
  static Future<void> pullRefreshThreshold() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      await HapticFeedback.vibrate();
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  /// 下拉刷新释放爆发震动
  static Future<void> pullRefreshRelease() async {
    if (_mode == HapticMode.off) return;
    if (_mode == HapticMode.basic) {
      await HapticFeedback.vibrate();
      return;
    }
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// 下拉刷新完成震动
  static Future<void> pullRefreshComplete() async {
    if (_mode != HapticMode.advanced) return;
    await HapticFeedback.lightImpact();
  }

  /// 边界碰撞震动（高级模式专用）
  static Future<void> boundaryImpact(double speed) async {
    if (_mode != HapticMode.advanced) return;
    if (speed > 1500) {
      await HapticFeedback.heavyImpact();
    } else if (speed > 800) {
      await HapticFeedback.mediumImpact();
    } else if (speed > 200) {
      await HapticFeedback.lightImpact();
    }
  }

  /// 蓄力震动（高级模式专用）
  static Future<void> chargingImpact(int level) async {
    if (_mode != HapticMode.advanced) return;
    switch (level) {
      case 0:
      case 1:
        await HapticFeedback.selectionClick();
        break;
      case 2:
      case 3:
        await HapticFeedback.lightImpact();
        break;
      case 4:
        await HapticFeedback.mediumImpact();
        break;
      case 5:
        await HapticFeedback.heavyImpact();
        break;
    }
  }
}
