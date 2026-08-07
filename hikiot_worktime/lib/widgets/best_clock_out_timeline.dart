import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/best_clockout_planner.dart';

/// 最佳下班时间柱状图：未来 [minutes] 根柱子，每分钟一根。
///
/// 柱子颜色 = 该分钟时刻下班的档位：绿=适合下班 / 黄=一般 / 红=别走。
/// 随时间滚动更新：最新的一分钟在右侧，旧的向左移出。
class BestClockOutTimeline extends StatelessWidget {
  const BestClockOutTimeline({
    super.key,
    required this.bands,
    this.minutes = 12,
  });

  /// 每分钟的档位，索引 0 = 现在这一分钟
  final List<WasteBand> bands;

  /// 展示的分钟数（柱子数量）
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final effective = bands.take(minutes).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '未来下班档位',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _legendDot(AppColors.success, '适合'),
            const SizedBox(width: 8),
            _legendDot(AppColors.warning, '一般'),
            const SizedBox(width: 8),
            _legendDot(AppColors.error, '别走'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < effective.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == effective.length - 1 ? 0 : 2,
                    ),
                    child: Container(
                      // 最新一根略高，视觉上区分"现在"
                      height: i == 0 ? 56 : 44,
                      decoration: BoxDecoration(
                        color: _colorOf(effective[i]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '最新一根 = 现在 · 每分钟更新一根',
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
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
