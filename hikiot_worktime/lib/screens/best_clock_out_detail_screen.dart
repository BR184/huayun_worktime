import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/metro_schedule.dart';
import '../services/storage_service.dart';
import '../utils/best_clockout_planner.dart';
import '../utils/work_time_calculator.dart';
import '../widgets/best_clock_out_entry.dart';
import '../widgets/best_clock_out_setup_dialog.dart';
import '../widgets/best_clock_out_timeline.dart';

/// 最佳下班时间详情页。
///
/// - 首次进入弹出初始化设置（出行方式/地铁方向），之后通过右上角
///   齿轮按钮调整，选择持久化到本地；
/// - 秒级刷新：建议时刻 + 实时倒计时（X 分 X 秒）证明数据在走；
/// - 柱状图每分钟一根柱子（绿=适合/黄=一般/红=别走），最新在右。
class BestClockOutDetailScreen extends StatefulWidget {
  const BestClockOutDetailScreen({super.key, this.checkInMinutes});

  /// 今日首次打卡分钟数（00:00 起算）；null = 未打卡
  final int? checkInMinutes;

  @override
  State<BestClockOutDetailScreen> createState() =>
      _BestClockOutDetailScreenState();
}

class _BestClockOutDetailScreenState extends State<BestClockOutDetailScreen> {
  final StorageService _storage = StorageService();
  CommuteMode _mode = CommuteMode.free;
  int _direction = 0;
  bool _ready = false;
  Timer? _ticker;
  int _timelineViewMinutes = 60; // 柱状图显示范围：10 或 60 分钟

  @override
  void initState() {
    super.initState();
    // 秒级刷新：倒计时与柱状图实时推进
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final modeName = await _storage.loadCommuteMode();
    final direction = await _storage.loadCommuteMetroDirection();
    if (!mounted) return;
    setState(() {
      _mode = CommuteMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => CommuteMode.free,
      );
      _direction = direction;
      _ready = true;
    });

    // 首次进入：强制初始化设置
    final hasSetting = await _storage.hasCommuteSetting();
    if (!hasSetting && mounted) {
      final saved = await BestClockOutSetupDialog.show(context);
      if (saved) await _reloadSettings();
    }
  }

  Future<void> _reloadSettings() async {
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

  Future<void> _openSettings() async {
    final saved = await BestClockOutSetupDialog.show(context);
    if (saved) await _reloadSettings();
  }

  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  /// 建议下班时刻（第几分钟）；null = 今日无建议
  int? _recommendedTime() {
    final checkIn = widget.checkInMinutes;
    if (checkIn == null) return null;
    return switch (_mode) {
      CommuteMode.free => BestClockOutPlanner.nextBestFreeTime(
        checkIn,
        _nowMinutes,
      ),
      CommuteMode.metro => BestClockOutPlanner.bestMetroPlan(
        line: HanyuJinguMetro.lines[_direction],
        checkInMinutes: checkIn,
        nowMinutes: _nowMinutes,
      )?.departTime,
      CommuteMode.bus => null,
    };
  }

  /// 未来 [minutes] 分钟的档位序列（索引 0 = 现在）
  List<WasteBand> _futureBands(int minutes) {
    final checkIn = widget.checkInMinutes;
    if (checkIn == null) return List.filled(minutes, WasteBand.poor);
    final now = _nowMinutes;
    return List.generate(minutes, (i) {
      final fraction = WorkTimeCalculator.wastedFraction(
        (now + i - checkIn) / 60.0,
      );
      return BestClockOutPlanner.bandOf(fraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('最佳下班时间')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final checkIn = widget.checkInMinutes;
    final recommended = _recommendedTime();
    final nowMinutes = _nowMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('最佳下班时间'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '出行方式设置',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 实时时钟卡：当前时间（秒级走时）+ 打卡时间 + 现在下班的工时
          _buildClockCard(),
          const SizedBox(height: 16),
          // 当前状态
          BestClockOutEntry(
            status: _currentStatus(),
            title: '${_modeName()}出行',
            subtitle: _currentSubtitle(),
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // 推荐一句话
          if (recommended != null)
            _buildRecommendation(recommended, nowMinutes)
          else
            _buildNoRecommendation(),
          const SizedBox(height: 16),
          // 实时柱状图（60 分钟全览，可切换 10 分钟视图）
          if (checkIn != null) ...[
            Row(
              children: [
                const Text(
                  '下班档位时间轴',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10 分钟')),
                    ButtonSegment(value: 60, label: Text('60 分钟')),
                  ],
                  selected: {_timelineViewMinutes},
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (selection) {
                    setState(() => _timelineViewMinutes = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            BestClockOutTimeline(
              bands: _futureBands(60),
              checkInMinutes: checkIn,
              viewMinutes: _timelineViewMinutes,
            ),
            const SizedBox(height: 16),
          ],
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
                    '在工时百分位接近 0（浪费 ≤1.2 分钟）的时刻下班可避免浪费。'
                    '右上角齿轮可随时调整出行方式。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 实时时钟卡：当前时间（秒级走时）+ 打卡时间 + 现在下班的工时
  Widget _buildClockCard() {
    final now = DateTime.now();
    final checkIn = widget.checkInMinutes;
    final current =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final checkInText = checkIn == null ? '--:--' : _minutesToText(checkIn);
    final nowHours = checkIn == null
        ? null
        : WorkTimeCalculator.formatBillableHours(
            (now.hour * 60 + now.minute - checkIn) / 60.0,
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '当前时间',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                current,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _clockItem('上班打卡', checkInText)),
              Container(width: 1, height: 28, color: AppColors.divider),
              Expanded(
                child: _clockItem('如果现在下班', nowHours ?? '--'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clockItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _modeName() {
    return switch (_mode) {
      CommuteMode.free => '自由',
      CommuteMode.metro => '地铁',
      CommuteMode.bus => '公交',
    };
  }

  BestClockOutStatus _currentStatus() {
    final checkIn = widget.checkInMinutes;
    if (checkIn == null) return BestClockOutStatus.unavailable;
    final fraction = WorkTimeCalculator.wastedFraction(
      (_nowMinutes - checkIn) / 60.0,
    );
    final band = BestClockOutPlanner.bandOf(fraction);
    return switch (band) {
      WasteBand.best => BestClockOutStatus.optimal,
      WasteBand.fair => BestClockOutStatus.approaching,
      WasteBand.poor => BestClockOutStatus.poor,
    };
  }

  String _currentSubtitle() {
    final checkIn = widget.checkInMinutes;
    if (checkIn == null) return '打卡后为你推荐最合适的下班时刻';
    final fraction = WorkTimeCalculator.wastedFraction(
      (_nowMinutes - checkIn) / 60.0,
    );
    final waste = BestClockOutPlanner.wasteMinutesOf(fraction);
    final band = BestClockOutPlanner.bandOf(fraction);
    final bandText = switch (band) {
      WasteBand.best => '最佳',
      WasteBand.fair => '一般',
      WasteBand.poor => '较差',
    };
    return '当前浪费 $waste 分钟（$bandText）';
  }

  /// 推荐 + 秒级倒计时
  Widget _buildRecommendation(int recommended, int nowMinutes) {
    final diff = recommended - nowMinutes;
    final seconds = diff * 60 - DateTime.now().second;
    final minute = seconds ~/ 60;
    final second = seconds % 60;

    final modeText = switch (_mode) {
      CommuteMode.free => '建议 $_minutesToText(recommended) 下班',
      CommuteMode.metro => _metroRecommendText(recommended),
      CommuteMode.bus => '公交模式即将上线',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modeText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            diff <= 0
                ? '现在就是最佳时刻'
                : '还有 $minute 分 ${second.toString().padLeft(2, '0')} 秒',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _metroRecommendText(int departTime) {
    final plan = BestClockOutPlanner.bestMetroPlan(
      line: HanyuJinguMetro.lines[_direction],
      checkInMinutes: widget.checkInMinutes!,
      nowMinutes: _nowMinutes,
    );
    if (plan == null) return '今日已无剩余班次';
    final bandText = switch (plan.band) {
      WasteBand.best => '最佳',
      WasteBand.fair => '一般',
      WasteBand.poor => '较差',
    };
    return '建议 $_minutesToText(plan.departTime) 下班'
        '（赶上 $_minutesToText(plan.trainTime) 地铁 · $bandText）';
  }

  Widget _buildNoRecommendation() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '打卡后这里会给出准确的建议下班时刻',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }

  String _minutesToText(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
