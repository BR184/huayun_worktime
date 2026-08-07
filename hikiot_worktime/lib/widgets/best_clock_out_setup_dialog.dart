import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/metro_schedule.dart';
import '../services/storage_service.dart';
import '../utils/best_clockout_planner.dart';

/// 最佳下班时间设置对话框（首次初始化与齿轮调整共用）。
///
/// 选择出行方式（自由/地铁/公交-即将上线），地铁时再选方向；
/// 确认后持久化到本地。
class BestClockOutSetupDialog extends StatefulWidget {
  const BestClockOutSetupDialog({super.key});

  /// 弹出并等待结果；返回 true 表示已保存设置。
  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BestClockOutSetupDialog(),
        ) ??
        false;
  }

  @override
  State<BestClockOutSetupDialog> createState() =>
      _BestClockOutSetupDialogState();
}

class _BestClockOutSetupDialogState extends State<BestClockOutSetupDialog> {
  final StorageService _storage = StorageService();
  CommuteMode _mode = CommuteMode.free;
  int _direction = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  /// 加载当前设置作为初始值
  Future<void> _loadCurrent() async {
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

  Future<void> _save() async {
    await _storage.saveCommuteMode(_mode.name);
    await _storage.saveCommuteMetroDirection(_direction);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.directions_transit, color: AppColors.primary),
          SizedBox(width: 8),
          Text('选择出行方式'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _mode == CommuteMode.free
                ? '开车/骑车下班，按工时凑整推荐时刻'
                : _mode == CommuteMode.metro
                ? '按汉峪金谷站地铁时刻表推荐（需提前 6 分钟到站）'
                : '公交模式即将上线',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (_mode == CommuteMode.metro) ...[
            const SizedBox(height: 12),
            const Text(
              '目的地',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                    onSelected: (_) => setState(() => _direction = i),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _save();
            if (context.mounted) Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
