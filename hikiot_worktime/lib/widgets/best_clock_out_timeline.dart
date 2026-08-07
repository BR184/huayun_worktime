import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/mock_time_service.dart';
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

  /// 所有连续绿色段的起点下标（每段第一根绿色柱子）
  List<int> get _greenStarts {
    final bands = _effective;
    final starts = <int>[];
    for (var i = 0; i < bands.length; i++) {
      if (bands[i] == WasteBand.best &&
          (i == 0 || bands[i - 1] != WasteBand.best)) {
        starts.add(i);
      }
    }
    return starts;
  }

  /// 拖动/点击位置 → 柱子下标
  int _indexFromDx(double dx, double width) {
    final count = _effective.length;
    final barWidth = width / count;
    final index = (dx / barWidth).floor().clamp(0, count - 1);
    return index;
  }

  String _minutesToText(int minutes) {
    // 取模支持跨天（如 23:35 + 60 分钟 → 00:35）
    final normalized = ((minutes % 1440) + 1440) % 1440;
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:'
        '${(normalized % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bands = _effective;
    // 视图切换后 _selected 可能残留旧范围的越界下标，渲染时安全收敛
    final selected = (_selected != null && _selected! < bands.length)
        ? _selected
        : null;
    final greenStarts = _greenStarts;
    final firstGreen = greenStarts.isEmpty ? null : greenStarts.first;
    // DEBUG 时间模拟器开启时使用模拟时钟
    final now = MockTimeService.instance.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部提示框：选中柱子的时间与原因
        SizedBox(
          height: 44,
          child: selected == null
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
              : _buildSelectedTooltip(bands, nowMinutes, selected),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Column(
              children: [
                // 绿色标签独立行：每段连续绿色的起点标时间，
                // 放在柱子区上方，不被高柱子遮挡
                SizedBox(
                  height: 16,
                  width: width,
                  child: Stack(
                    children: [
                      for (final start in greenStarts)
                        Positioned(
                          left: _labelLeft(start, bands.length, width),
                          child: Text(
                            _minutesToText(nowMinutes + start),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    setState(
                      () => _selected = _indexFromDx(
                        details.localPosition.dx,
                        width,
                      ),
                    );
                  },
                  onHorizontalDragStart: (details) {
                    setState(
                      () => _selected = _indexFromDx(
                        details.localPosition.dx,
                        width,
                      ),
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(
                      () => _selected = _indexFromDx(
                        details.localPosition.dx,
                        width,
                      ),
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
                                    height: selected == i
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
                        // 折线：从标签行引到各绿色段起点的柱子顶端
                        if (greenStarts.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GreenGuidesPainter(
                                barCenters: [
                                  for (final s in greenStarts)
                                    (s + 0.5) / bands.length * width,
                                ],
                                guideLength: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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

  /// 选中柱子的提示框：时间 + 具体浪费分钟 + 档位结论（不重复区间文案）
  Widget _buildSelectedTooltip(
    List<WasteBand> bands,
    int nowMinutes,
    int selected,
  ) {
    final band = bands[selected];
    final color = _colorOf(band);
    final conclusion = switch (band) {
      WasteBand.best => '适合下班',
      WasteBand.fair => '一般',
      WasteBand.poor => '别走',
    };
    var wasteText = '';
    final checkIn = widget.checkInMinutes;
    if (checkIn != null) {
      final fraction = WorkTimeCalculator.wastedFraction(
        (nowMinutes + selected - checkIn) / 60.0,
      );
      wasteText = '浪费 ${BestClockOutPlanner.wasteMinutesOf(fraction)} 分钟';
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
              '${_minutesToText(nowMinutes + selected)} 下班 · $wasteText · $conclusion',
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

  /// 绿色段起点标签的左侧位置：按柱子中心对齐并夹在容器内防裁切
  double _labelLeft(int start, int bandCount, double width) {
    const labelWidth = 30.0;
    final barCenter = (start + 0.5) / bandCount * width;
    return (barCenter - labelWidth / 2).clamp(0.0, width - labelWidth);
  }

  Color _colorOf(WasteBand band) {
    return switch (band) {
      WasteBand.best => AppColors.success,
      WasteBand.fair => AppColors.warning,
      WasteBand.poor => AppColors.error,
    };
  }
}

/// 绿色段折线指引画布：从柱子区顶部（标签行下缘）向下引竖线，
/// 落进各绿色段起点的柱子顶端（普通柱顶端在区内 18px 处，
/// 首柱 8px，选中柱 0px，统一画到 18px 即保证连接到柱子）。
class _GreenGuidesPainter extends CustomPainter {
  const _GreenGuidesPainter({
    required this.barCenters,
    required this.guideLength,
  });

  /// 各绿色段起点的柱子中心 x 坐标
  final List<double> barCenters;

  /// 引导线长度（柱子区顶部向下的像素数）
  final double guideLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final center in barCenters) {
      canvas.drawLine(Offset(center, 0), Offset(center, guideLength), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GreenGuidesPainter oldDelegate) {
    return oldDelegate.barCenters.length != barCenters.length ||
        oldDelegate.guideLength != guideLength;
  }
}
