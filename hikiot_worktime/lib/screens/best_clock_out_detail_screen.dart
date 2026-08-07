import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/metro_schedule.dart';
import '../services/storage_service.dart';
import '../utils/best_clockout_planner.dart';
import '../widgets/best_clock_out_entry.dart';

/// 最佳下班时间详情页。
///
/// 用户先选择出行方式（自由/地铁/公交-即将上线），地铁需再选方向，
/// 选择持久化到本地；页面展示当前状态与最高性价比的下班建议。
class BestClockOutDetailScreen extends StatefulWidget {
  const BestClockOutDetailScreen({
    super.key,
    required this.status,
    required this.title,
    required this.subtitle,
    this.checkInMinutes,
  });

  final BestClockOutStatus status;
  final String title;
  final String subtitle;

  /// 今日首次打卡的分钟数（00:00 起算），用于计算推荐班次
  final int? checkInMinutes;

  @override
  State<BestClockOutDetailScreen> createState() =>
      _BestClockOutDetailScreenState();
}

class _BestClockOutDetailScreenState extends State<BestClockOutDetailScreen> {
  final StorageService _storage = StorageService();
  CommuteMode _mode = CommuteMode.free;
  int _direction = 0;

  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final modeName = await _storage.loadCommuteMode();
    final direction = await _storage.loadCommuteMetroDirection();
    if (mounted) {
      setState(() {
        _mode = CommuteMode.values.firstWhere(
          (m) => m.name == modeName,
          orElse: () => CommuteMode.free,
        );
        _direction = direction;
      });
    }
  }

  Future<void> _selectMode(CommuteMode mode) async {
    setState(() => _mode = mode);
    await _storage.saveCommuteMode(mode.name);
  }

  Future<void> _selectDirection(int direction) async {
    setState(() => _direction = direction);
    await _storage.saveCommuteMetroDirection(direction);
  }

  /// 今日打卡分钟数（由每日页传入）；未传时仅展示配置与说明。
  int? _resolveCheckInMinutes() => widget.checkInMinutes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最佳下班时间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 出行方式选择
          Text(
            '出行方式',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<CommuteMode>(
            segments: const [
              ButtonSegment(
                value: CommuteMode.free,
                icon: Icon(Icons.directions_car),
                label: Text('自由'),
              ),
              ButtonSegment(
                value: CommuteMode.metro,
                icon: Icon(Icons.subway),
                label: Text('地铁'),
              ),
              ButtonSegment(
                value: CommuteMode.bus,
                icon: Icon(Icons.directions_bus),
                label: Text('公交'),
                enabled: false,
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _selectMode(selection.first),
          ),
          const SizedBox(height: 12),
          if (_mode == CommuteMode.metro) _buildMetroDirectionSelector(),
          const SizedBox(height: 16),
          // 当前状态
          BestClockOutEntry(
            status: widget.status,
            title: widget.title,
            subtitle: widget.subtitle,
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
                    '在工时百分位接近 0（浪费 ≤1.2 分钟）的时刻下班，可避免这部分浪费。'
                    '浪费档位：0.00~0.02 最佳 / 0.03~0.05 一般 / 0.06~0.09 较差。',
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
          if (_mode == CommuteMode.bus)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '公交模式即将上线：将结合实时到站（车来了协议）与公交站距离给出建议。',
                style: TextStyle(fontSize: 12, color: AppColors.warningDark),
              ),
            ),
        ],
      ),
    );
  }

  /// 地铁方向选择
  Widget _buildMetroDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目的地（汉峪金谷站）',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < HanyuJinguMetro.lines.length; i++)
              ChoiceChip(
                label: Text(
                  '${HanyuJinguMetro.lines[i].name}'
                  '（${HanyuJinguMetro.lines[i].destination}）',
                ),
                selected: _direction == i,
                onSelected: (_) => _selectDirection(i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '首班 ${HanyuJinguMetro.lines[_direction].firstTime}'
          ' · 末班 ${HanyuJinguMetro.lines[_direction].lastTime}'
          ' · 到站步行约 6 分钟',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        _buildMetroRecommendation(),
      ],
    );
  }

  /// 地铁推荐：以"工时浪费 + 等待"取性价比最高的下班时刻
  Widget _buildMetroRecommendation() {
    final checkIn = _resolveCheckInMinutes();
    if (checkIn == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '打卡后这里会给出最高性价比的下班班次',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final nowMinutes = _nowMinutes;
    final line = HanyuJinguMetro.lines[_direction];
    final plan = BestClockOutPlanner.bestMetroPlan(
      line: line,
      checkInMinutes: checkIn,
      nowMinutes: nowMinutes,
    );
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '今日已无剩余班次',
          style: TextStyle(fontSize: 12, color: AppColors.error),
        ),
      );
    }

    final bandText = switch (plan.band) {
      WasteBand.best => '最佳',
      WasteBand.fair => '一般',
      WasteBand.poor => '较差',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '推荐下班班次',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _planRow('下班时刻', _minutesToText(plan.departTime)),
          _planRow('地铁到站', _minutesToText(plan.trainTime)),
          _planRow('工时浪费', '${plan.wasteMinutes} 分钟（$bandText）'),
          _planRow('还需等待', '${plan.waitMinutes} 分钟'),
        ],
      ),
    );
  }

  Widget _planRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _minutesToText(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
