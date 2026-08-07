import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/best_clock_out_entry.dart';

/// 最佳下班时间详情页。
///
/// 当前为入口配套框架：展示凑整建议与说明；
/// 后续接入济南公交实时数据（车来了协议）后，
/// 在此展示附近线路下一班来车时刻与推荐下班时间。
class BestClockOutDetailScreen extends StatelessWidget {
  const BestClockOutDetailScreen({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
  });

  final BestClockOutStatus status;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最佳下班时间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前状态
          BestClockOutEntry(
            status: status,
            title: title,
            subtitle: subtitle,
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // 功能说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '工时统计只保留一位小数，百分位会被截断（如 11.19h 只计 11.1h）。'
                    '在工时正好凑整（如 8.0h）的时刻下班，可避免这部分浪费。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 公交数据占位（后续接入车来了实时班次）
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '公交班次',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '济南公交实时数据接入后，这里将展示：\n'
                  '• 附近线路的下一班来车时刻\n'
                  '• 推荐下班时间（工时凑整 + 赶上最近班次）\n'
                  '• 地铁首末班与间隔参考',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warningDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(switch (status) {
              BestClockOutStatus.optimal => '当前处于最佳下班窗口',
              BestClockOutStatus.approaching => '等待凑整时刻',
              BestClockOutStatus.unavailable => '暂不可用，打卡后查看',
            }, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}
