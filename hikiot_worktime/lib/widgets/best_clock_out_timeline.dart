import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/best_clockout_planner.dart';
import '../utils/work_time_calculator.dart';

/// 最佳下班时间柱状图（60 分钟全览，可缩放 10/60 分钟）。
///
/// - 柱子颜色 = 该分钟时刻下班的档位：绿=适合 / 黄=一般 / 红=别走；
/// - 左右拖动/点击选中某根柱子：柱子放大，顶部提示框显示
///   该时刻的具体时间与推荐原因；
/// - 连续绿色段的第一根柱子带折线标记（▼ + 时间），快速定位
///   最近的最佳下班窗口；
/// - 60 分钟视图标注"现在 / +30 分钟 / +60 分钟"三个时间点；
///   10 分钟视图每根柱子下方倾斜标注精确时间（HH:MM）。
class BestClockOutTimeline extends StatefulWidget {
  const BestClockOutTimeline({
    super.key,
    required this.bands,
    required this.checkInMinutes,
    this.viewMinutes = 60,
  });

  /// 未来 60 分钟每分钟的档位（索引 0 = 现在这一分钟）
  final List<WasteBand> bands;

  /// 今日首次打卡分钟数，用于提示框计算具体浪费分钟
  final int? checkInMinutes;

  /// 显示范围：10 或 60 分钟
  final int viewMinutes;

  @override
  State<BestClockOutTimeline> createState() => _BestClockOutTimelineState();
}

class _BestClockOutTimelineState extends State<BestClockOutTimeline> {
  /// 当前选中的柱子下标（相对显示范围），null = 未选中
  int? _selected;

  List<WasteBand> get _effective =>
      widget.bands.take(widget.viewMinutes).toList();

  /// 连续绿色段第一根柱子的下标；无则 null
  int? get _firstGreenIndex {
    final bands = _effective;
    for (var i = 0; i < bands.length; i++) {
      if (bands[i] == WasteBand.best) return i;
    }
    return null;
  }

  /// 拖动/点击位置 → 柱子下标
  int _indexFromDx(double dx, double width) {
    final count = _effective.length;
    final barWidth = width / count;
    final index = (dx / barWidth).floor().clamp(0, count - 1);
    return index;
  }

  String _minutesToText(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  String _reasonText(WasteBand band) {
    return switch (band) {
      WasteBand.best => '浪费 ≤1.2 分钟，适合下班',
      WasteBand.fair => '浪费 1.8~3 分钟，一般',
      WasteBand.poor => '浪费 3.6~5.4 分钟，别走',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bands = _effective;
    final firstGreen = _firstGreenIndex;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部提示框：选中柱子的时间与原因
        SizedBox(
          height: 44,
          child: _selected == null
              ? Row(
                  children: [
                    Text(
                      '滑动查看每一分钟的下班档位',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const Spacer(),
                    if (firstGreen != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_down,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '最佳窗口 ${_minutesToText(nowMinutes + firstGreen)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                  ],
                )
              : _buildSelectedTooltip(bands, nowMinutes),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                setState(
                  () =>
                      _selected = _indexFromDx(details.localPosition.dx, width),
                );
              },
              onHorizontalDragStart: (details) {
                setState(
                  () =>
                      _selected = _indexFromDx(details.localPosition.dx, width),
                );
              },
              onHorizontalDragUpdate: (details) {
                setState(
                  () =>
                      _selected = _indexFromDx(details.localPosition.dx, width),
                );
              },
              child: SizedBox(
                height: 64,
                width: width,
                child: Stack(
                  children: [
                    // 柱子
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < bands.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 1,
                                right: i == bands.length - 1 ? 0 : 1,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 80),
                                height: _selected == i
                                    ? 64
                                    : i == 0
                                    ? 56
                                    : 46,
                                decoration: BoxDecoration(
                                  color: _colorOf(bands[i]),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 连续绿色首柱标记（折线 + 时间）
                    if (firstGreen != null)
                      Positioned(
                        left: (firstGreen + 0.5) / bands.length * width - 18,
                        top: 0,
                        child: Column(
                          children: [
                            Text(
                              _minutesToText(nowMinutes + firstGreen),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // 底部时间标注
        if (widget.viewMinutes == 60)
          _buildHourLabels(nowMinutes)
        else
          _buildMinuteLabels(
            nowMinutes,
            bands.length,
            MediaQuery.of(context).size.width,
          ),
      ],
    );
  }

  /// 60 分钟视图：现在 / +30 / +60 三个时间点
  Widget _buildHourLabels(int nowMinutes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '现在 ${_minutesToText(nowMinutes)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          '+30 分钟 ${_minutesToText(nowMinutes + 30)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          '+60 分钟 ${_minutesToText(nowMinutes + 60)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// 10 分钟视图：每根柱子下方倾斜时间标签
  Widget _buildMinuteLabels(int nowMinutes, int count, double width) {
    return SizedBox(
      height: 34,
      width: width,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i / count * width,
              width: width / count,
              child: Transform.rotate(
                angle: -0.5, // 倾斜排开所有标签
                child: Text(
                  _minutesToText(nowMinutes + i),
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedTooltip(List<WasteBand> bands, int nowMinutes) {
    final i = _selected!;
    final band = bands[i];
    final color = _colorOf(band);
    final checkIn = widget.checkInMinutes;
    var wasteText = '';
    if (checkIn != null) {
      final fraction = WorkTimeCalculator.wastedFraction(
        (nowMinutes + i - checkIn) / 60.0,
      );
      wasteText = ' · 浪费 ${BestClockOutPlanner.wasteMinutesOf(fraction)} 分钟';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${_minutesToText(nowMinutes + i)} 下班：${_reasonText(band)}$wasteText',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorOf(WasteBand band) {
    return switch (band) {
      WasteBand.best => AppColors.success,
      WasteBand.fair => AppColors.warning,
      WasteBand.poor => AppColors.error,
    };
  }
}
