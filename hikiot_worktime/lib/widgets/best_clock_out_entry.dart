import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 最佳下班时间入口的状态：颜色即状态。
///
/// - [BestClockOutStatus.optimal]：现在就是最佳下班时间（绿色）
/// - [BestClockOutStatus.approaching]：接近但还没到，显示建议时刻（琥珀色）
/// - 不适用（未打卡/已下班/非今日）时不渲染该入口
enum BestClockOutStatus {
  /// 现在是最佳下班时间
  optimal,

  /// 接近最佳，显示建议下班时刻
  approaching,
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
    final isOptimal = status == BestClockOutStatus.optimal;
    final color = isOptimal ? AppColors.success : AppColors.warning;
    final lightColor = isOptimal
        ? AppColors.successLight
        : AppColors.warningLight;

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
              Icon(
                isOptimal ? Icons.check_circle : Icons.schedule,
                color: color,
                size: 20,
              ),
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
