import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/metro_schedule.dart';
import '../services/mock_time_service.dart';
import '../utils/best_clockout_planner.dart';

/// 最佳下班时间入口的状态：颜色即状态。
///
/// - [BestClockOutStatus.optimal]：现在是最佳下班时间（绿色）
/// - [BestClockOutStatus.approaching]：接近但还没到（琥珀色）
/// - [BestClockOutStatus.poor]：现在下班浪费较多（红色）
/// - [BestClockOutStatus.unavailable]：暂不可用（未打卡）（灰色）
enum BestClockOutStatus {
  /// 现在是最佳下班时间
  optimal,

  /// 接近最佳
  approaching,

  /// 现在下班浪费较多
  poor,

  /// 暂不可用：未打卡
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
      BestClockOutStatus.poor => (
        AppColors.error,
        AppColors.errorLight,
        Icons.error_outline,
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

/// 每日页"最佳下班时间"实时横幅。
///
/// 独立 Timer 每秒刷新，用户对时间敏感：状态颜色与文案
/// 随时钟推进实时更新（分钟级变化，秒级驱动重绘）。
class BestClockOutBanner extends StatefulWidget {
  const BestClockOutBanner({
    super.key,
    required this.checkInMinutes,
    required this.mode,
    required this.metroDirection,
    required this.metroWalkMinutes,
    required this.onTap,
  });

  /// 今日首次打卡分钟数；null = 未打卡
  final int? checkInMinutes;

  final CommuteMode mode;
  final int metroDirection;

  /// 到地铁站步行分钟（设置中可调，默认 7）
  final int metroWalkMinutes;

  final VoidCallback onTap;

  @override
  State<BestClockOutBanner> createState() => _BestClockOutBannerState();
}

class _BestClockOutBannerState extends State<BestClockOutBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒刷新，保证时间敏感信息实时可见
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.checkInMinutes;

    // DEBUG 时间模拟器开启时使用模拟时钟
    final now = MockTimeService.instance.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // 未打卡：灰色分栏卡，提示打卡
    if (checkIn == null) {
      return _buildCard(
        color: AppColors.textSecondary,
        bands: List.filled(10, WasteBand.poor),
        title: '最佳下班时间',
        subtitle: '打卡后为你推荐最合适的下班时刻',
      );
    }

    // 分钟整数精确残差，避免 9.1h 等整十分位被浮点下界误判
    final waste = BestClockOutPlanner.wasteMinutesOf(
      BestClockOutPlanner.wasteFractionFromMinutes(nowMinutes - checkIn),
    );
    final band = BestClockOutPlanner.bandOf(
      BestClockOutPlanner.wasteFractionFromMinutes(nowMinutes - checkIn),
    );
    final bands = _next10Bands(checkIn, nowMinutes);
    // 最近绿色窗口起点（未来 10 分钟内）
    final firstGreen = _firstGreenIn(bands);

    // 标题与档位色
    final color = switch (band) {
      WasteBand.best => AppColors.success,
      WasteBand.fair => AppColors.warning,
      WasteBand.poor => AppColors.error,
    };
    final title = switch (band) {
      WasteBand.best => '现在下班正合适',
      WasteBand.fair => '现在下班浪费 $waste 分钟',
      WasteBand.poor => '现在下班浪费 $waste 分钟',
    };
    // 小字：最近最佳下班时间（最近绿段起点）
    final subtitle = firstGreen != null
        ? '最近最佳下班时间 ${_formatMinutes(nowMinutes + firstGreen)}'
        : '暂无合适时刻';

    return _buildCard(
      color: color,
      bands: bands,
      title: title,
      subtitle: subtitle,
    );
  }

  /// 分栏卡片：白底 + 状态色边框；左侧迷你柱状图，右侧标题
  Widget _buildCard({
    required Color color,
    required List<WasteBand> bands,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 左侧：最近 10 分钟迷你柱状图
                SizedBox(
                  width: 84,
                  height: 30,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < bands.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == bands.length - 1 ? 0 : 2,
                            ),
                            child: Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: _miniBarColor(bands[i]),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧：标题 + 小字
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
      ),
    );
  }

  /// 未来 10 分钟档位（自由看残差，地铁看总浪费）
  List<WasteBand> _next10Bands(int checkIn, int nowMinutes) {
    return List.generate(10, (i) {
      final depart = nowMinutes + i;
      if (widget.mode == CommuteMode.metro) {
        return BestClockOutPlanner.metroWasteDetail(
          line: HanyuJinguMetro.lines[widget.metroDirection],
          checkInMinutes: checkIn,
          departTime: depart,
          walkMinutes: widget.metroWalkMinutes,
        ).band;
      }
      return BestClockOutPlanner.bandOf(
        BestClockOutPlanner.wasteFractionFromMinutes(depart - checkIn),
      );
    });
  }

  int? _firstGreenIn(List<WasteBand> bands) {
    for (var i = 0; i < bands.length; i++) {
      if (bands[i] == WasteBand.best) return i;
    }
    return null;
  }

  Color _miniBarColor(WasteBand band) {
    return switch (band) {
      WasteBand.best => AppColors.success,
      WasteBand.fair => AppColors.warning,
      WasteBand.poor => AppColors.error,
    };
  }

  String _formatMinutes(int minutes) {
    final normalized = ((minutes % 1440) + 1440) % 1440;
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:'
        '${(normalized % 60).toString().padLeft(2, '0')}';
  }
}
