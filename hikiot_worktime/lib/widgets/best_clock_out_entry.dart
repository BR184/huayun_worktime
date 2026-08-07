import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/metro_schedule.dart';
import '../utils/best_clockout_planner.dart';
import '../utils/work_time_calculator.dart';

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
    if (checkIn == null) {
      return BestClockOutEntry(
        status: BestClockOutStatus.unavailable,
        title: '最佳下班时间',
        subtitle: '打卡后为你推荐最合适的下班时刻',
        onTap: widget.onTap,
      );
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final elapsed = nowMinutes - checkIn;
    final fraction = WorkTimeCalculator.wastedFraction(elapsed / 60.0);
    final waste = BestClockOutPlanner.wasteMinutesOf(fraction);
    final band = BestClockOutPlanner.bandOf(fraction);

    final (status, title, subtitle) = switch (widget.mode) {
      CommuteMode.free => (
        _statusOf(band),
        band == WasteBand.best ? '现在是最佳下班时间' : '现在下班浪费 $waste 分钟',
        band == WasteBand.best ? '工时接近整点，浪费仅 $waste 分钟' : '等到整点再走可避免浪费',
      ),
      CommuteMode.metro => _metroBannerText(checkIn, nowMinutes, band, waste),
      CommuteMode.bus => (
        BestClockOutStatus.unavailable,
        '公交模式即将上线',
        '在设置中选择出行方式',
      ),
    };

    return BestClockOutEntry(
      status: status,
      title: title,
      subtitle: subtitle,
      onTap: widget.onTap,
    );
  }

  BestClockOutStatus _statusOf(WasteBand band) {
    return switch (band) {
      WasteBand.best => BestClockOutStatus.optimal,
      WasteBand.fair => BestClockOutStatus.approaching,
      WasteBand.poor => BestClockOutStatus.poor,
    };
  }

  (BestClockOutStatus, String, String) _metroBannerText(
    int checkInMinutes,
    int nowMinutes,
    WasteBand band,
    double waste,
  ) {
    final line = HanyuJinguMetro.lines[widget.metroDirection];
    final catchPlan = BestClockOutPlanner.currentMetroCatch(
      line: line,
      checkInMinutes: checkInMinutes,
      nowMinutes: nowMinutes,
      walkMinutes: widget.metroWalkMinutes,
    );
    final trainText = catchPlan == null
        ? '已无班次'
        : '下一班 ${_formatMinutes(catchPlan.trainTime)}';
    return switch (band) {
      WasteBand.best => (
        BestClockOutStatus.optimal,
        '现在下班正合适',
        '$trainText · 浪费仅 $waste 分钟',
      ),
      WasteBand.fair => (
        BestClockOutStatus.approaching,
        '现在下班浪费 $waste 分钟',
        '$trainText · 建议等整点时刻',
      ),
      WasteBand.poor => (
        BestClockOutStatus.poor,
        '现在下班浪费 $waste 分钟',
        '$trainText · 等整点再走更划算',
      ),
    };
  }

  String _formatMinutes(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
