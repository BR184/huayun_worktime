import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 最佳下班时间入口的状态：颜色即状态。
///
/// - [BestClockOutStatus.optimal]：现在就是最佳下班时间（绿色）
/// - [BestClockOutStatus.approaching]：接近但还没到，显示建议时刻（琥珀色）
/// - [BestClockOutStatus.unavailable]：暂不可用（未打卡/已下班）（灰色）
enum BestClockOutStatus {
  /// 现在是最佳下班时间
  optimal,

  /// 接近最佳，显示建议下班时刻
  approaching,

  /// 暂不可用：未打卡或已下班
  unavailable,
}

/// 每日页"最佳下班时间"入口。
///
/// 高频功能入口：胶囊形状态条融入实时工时信息卡片，
/// 颜色本身即代表当前是否处于最佳下班时间，点击进入详情页。
class BestClockOutEntry extends StatelessWidget {
  const BestClockOutEntry({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final BestClockOutStatus status;

  /// 主文案，如"现在是最佳下班时间" / "最佳下班 18:35"
  final String title;

  /// 副文案，如"再等 4 分钟，工时正好 8.0h"
  final String subtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, lightColor, icon) = switch (status) {
      BestClockOutStatus.optimal => (
        AppColors.success,
        AppColors.successLight,
        Icons.check_circle,
      ),
      BestClockOutStatus.approaching => (
        AppColors.warning,
        AppColors.warningLight,
        Icons.schedule,
      ),
      BestClockOutStatus.unavailable => (
        AppColors.textSecondary,
        AppColors.surfaceSunken,
        Icons.info_outline,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: lightColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
