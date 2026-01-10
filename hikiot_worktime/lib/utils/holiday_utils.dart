import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../core/theme/theme.dart';

/// 节假日工具类
/// 封装节假日更新的校验、API调用和UI反馈逻辑
class HolidayUtils {
  /// 处理节假日更新流程
  ///
  /// [context] 上下文，用于显示SnackBar
  /// [year] 要更新的年份
  /// [month] 当前显示的月份（用于校验是否超过当前时间太多）
  /// [storage] 存储服务实例
  /// [onLoading] Loading状态回调
  /// [onSuccess] 成功回调（通常用于刷新页面数据）
  static Future<void> handleUpdateHolidays({
    required BuildContext context,
    required int year,
    required int month,
    required StorageService storage,
    required Function(bool) onLoading,
    required VoidCallback onSuccess,
  }) async {
    // 验证年份范围:2010年到下个月末
    final now = DateTime.now();
    final nextMonthEnd = DateTime(now.year, now.month + 2, 0); // 下个月最后一天
    final targetMonthEnd = DateTime(year, month + 1, 0); // 选择月份最后一天

    if (year < 2010) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('无法更新2010年之前的节假日'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (targetMonthEnd.isAfter(nextMonthEnd)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法更新${now.year}年${now.month + 1}月之后的节假日'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    onLoading(true);

    try {
      final success = await storage.updateHolidaysFromAPI(year);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '节假日更新成功' : '节假日更新失败，使用默认规则'),
            backgroundColor: success ? AppColors.success : AppColors.warning,
          ),
        );
      }

      if (success) {
        onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('节假日更新失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      onLoading(false);
    }
  }
}
