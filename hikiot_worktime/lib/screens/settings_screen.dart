import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/hikiot_api_client.dart';
import '../services/notification_service.dart';
import '../services/reminder_coordinator.dart';
import '../services/settings_repository.dart';
import '../services/team_context_service.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_helper.dart';
import '../widgets/haptic_refresh_indicator.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'phone_permission_guide.dart';
import 'feature_guide_page.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final SessionService _sessionService = SessionService();
  final ReminderCoordinator _reminderCoordinator = ReminderCoordinator();
  late final SettingsRepository _settingsRepository;
  HikiotApiClient? _apiClient;
  bool _isLoading = true;

  // 午休时间设置
  TimeOfDay _lunchStartTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _lunchEndTime = const TimeOfDay(hour: 13, minute: 0);

  // 智能排序开关
  bool _smartSort = true;

  // 基础目标百分比
  int _baseTarget = 120;
  bool _extendedTargetRange = false; // 扩展目标范围开关

  // 震动模式
  HapticMode _hapticMode = HapticMode.advanced;

  // 打卡提醒设置
  bool _morningReminderEnabled = false;
  bool _eveningReminderEnabled = false;
  TimeOfDay _morningReminderTime = const TimeOfDay(hour: 8, minute: 55);
  TimeOfDay _eveningReminderTime = const TimeOfDay(hour: 21, minute: 0);

  // 调试工具开关
  bool _debugToolsEnabled = false;

  // 跨天时间点
  TimeOfDay _crossDayTime = const TimeOfDay(hour: 4, minute: 0);

  // 用户信息
  String? _userName;
  String? _teamNo;
  String? _teamName;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(storage: _storage);
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _settingsRepository.load();

      _lunchStartTime = _parseTime(snapshot.lunchStartTime, _lunchStartTime);
      _lunchEndTime = _parseTime(snapshot.lunchEndTime, _lunchEndTime);
      _smartSort = snapshot.smartSort;
      _baseTarget = snapshot.baseTarget;
      _hapticMode =
          HapticMode.values[snapshot.hapticModeIndex.clamp(
            0,
            HapticMode.values.length - 1,
          )];
      _crossDayTime = _timeFromMinutes(snapshot.crossDayMinutes);

      final reminderSettings = snapshot.reminderSettings;
      _morningReminderEnabled = reminderSettings.morningEnabled;
      _eveningReminderEnabled = reminderSettings.eveningEnabled;
      _morningReminderTime = TimeOfDay(
        hour: reminderSettings.morningHour,
        minute: reminderSettings.morningMinute,
      );
      _eveningReminderTime = TimeOfDay(
        hour: reminderSettings.eveningHour,
        minute: reminderSettings.eveningMinute,
      );

      _extendedTargetRange = snapshot.extendedTargetRange;
      _debugToolsEnabled = snapshot.debugToolsEnabled;
      _userName = snapshot.userName;
      _teamNo = snapshot.teamNo;
      _teamName = snapshot.teamName;

      // 初始化 API 客户端
      final token = snapshot.token;
      if (token != null && token.isNotEmpty) {
        _apiClient = HikiotApiClient(token: token);
      }
    } catch (e) {
      // 忽略加载设置失败
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      await _settingsRepository.saveLunchTimes(
        start: _formatTime(_lunchStartTime),
        end: _formatTime(_lunchEndTime),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 格式化时间
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _timeFromMinutes(int minutes) {
    final normalized = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  /// 选择时间
  Future<void> _selectTime(bool isStart) async {
    final initialTime = isStart ? _lunchStartTime : _lunchEndTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticUtils.selectionClick(); // 选择时间确认后震动
      setState(() {
        if (isStart) {
          _lunchStartTime = picked;
        } else {
          _lunchEndTime = picked;
        }
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : HapticRefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader('工时计算', Icons.access_time),
                  const SizedBox(height: 12),
                  _buildLunchTimeSettings(),
                  const SizedBox(height: 12),
                  _buildCrossDaySettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeaderWithHelp(
                    '打卡提醒（实验性功能）',
                    Icons.notifications_active,
                    _showReminderHelp,
                  ),
                  const SizedBox(height: 12),
                  _buildPunchReminderSettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('目标显示', Icons.flag),
                  const SizedBox(height: 12),
                  _buildBaseTargetSettings(),
                  const SizedBox(height: 12),
                  _buildSmartSortSettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('震动反馈', Icons.vibration),
                  const SizedBox(height: 12),
                  _buildHapticSettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('账号管理', Icons.account_circle),
                  const SizedBox(height: 12),
                  _buildAccountSettings(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('帮助与反馈(其实没有反馈功能)', Icons.help_outline),
                  const SizedBox(height: 12),
                  _buildHelpSettings(),
                  const SizedBox(height: 24),
                  if (!kReleaseMode) ...[
                    _buildDebugToolsHeader(),
                    if (_debugToolsEnabled) ...[
                      const SizedBox(height: 12),
                      _buildDeveloperSettings(),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  /// 构建带帮助按钮的分组标题
  Widget _buildSectionHeaderWithHelp(
    String title,
    IconData icon,
    VoidCallback onHelp,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            HapticUtils.lightImpact();
            onHelp();
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示提醒功能帮助
  void _showReminderHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('打卡提醒说明'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection('📌 上班提醒', [
                '• 未打卡 → 今天还没有打上班卡，别忘了打卡！',
                '• 已打卡 → 已打上班卡：HH:MM',
                '• 无网络 → 记得检查今天的打卡状态哦~',
                '• Token失效 → 提示重新登录',
                '• 节假日/周末 → 不发送通知',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('🌙 下班提醒', [
                '• 未打卡 → 今天还没有打下班卡，别忘了打卡！',
                '• 已打卡工时<8H → 显示时间+工时不足提醒',
                '• 已打卡工时≥8H → 显示时间+工时',
                '• 无网络 → 记得检查今天的打卡和工时状态~',
                '• Token失效 → 提示重新登录',
                '• 节假日/周末 → 不发送通知',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('🔔 测试通知', [
                '• 点击测试后退出APP',
                '• 10秒后依次发送3条测试通知',
                '• 第1条：测试成功提示',
                '• 第2条：模拟上班打卡提醒',
                '• 第3条：模拟下班打卡提醒',
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '周末(除调休上班)和节假日不会发送提醒',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 实验性功能警告
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 6),
                        Text(
                          '实验性功能',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '此功能采用本地闹钟而非服务器推送，在以下情况可能无法正常提醒：',
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 小米/华为/OPPO/vivo等国产系统省电策略\n'
                      '• 应用被系统后台杀死\n'
                      '• 未开启自启动权限\n'
                      '• 开启了电池优化',
                      style: TextStyle(fontSize: 11, color: Colors.red[600]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '建议：点击"权限设置"按照指引配置手机权限',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 构建帮助分组
  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              item,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  /// 基础目标设置卡片
  Widget _buildBaseTargetSettings() {
    final maxValue = _extendedTargetRange ? 300.0 : 160.0;
    final divisions = _extendedTargetRange
        ? 20
        : 6; // 100-300每10%一档=20档，100-160每10%一档=6档
    // 如果关闭扩展范围且当前值超过160，自动调整到160
    if (!_extendedTargetRange && _baseTarget > 160) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _baseTarget = 160);
        _settingsRepository.saveTargetSettings(
          extendedTargetRange: false,
          baseTarget: 160,
        );
      });
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '基础目标',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_baseTarget%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 扩展范围开关
            Row(
              children: [
                Icon(Icons.expand, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '更多挡位',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Spacer(),
                Switch(
                  value: _extendedTargetRange,
                  onChanged: (value) async {
                    await HapticUtils.selectionClick();
                    setState(() {
                      _extendedTargetRange = value;
                      if (!value && _baseTarget > 160) {
                        _baseTarget = 160;
                      }
                    });
                    await _settingsRepository.saveTargetSettings(
                      extendedTargetRange: value,
                      baseTarget: _baseTarget,
                    );
                  },
                  activeThumbColor: Colors.blue[700],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue[700],
                inactiveTrackColor: Colors.blue[100],
                thumbColor: Colors.blue[700],
                overlayColor: Colors.blue.withValues(alpha: 0.2),
                valueIndicatorColor: Colors.blue[700],
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                value: _baseTarget.toDouble().clamp(100, maxValue),
                min: 100,
                max: maxValue,
                divisions: divisions,
                label: '$_baseTarget%',
                onChanged: (value) async {
                  await HapticUtils.selectionClick();
                  setState(() => _baseTarget = value.round());
                },
                onChangeEnd: (value) async {
                  await _settingsRepository.saveBaseTarget(value.round());
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _extendedTargetRange
                  ? [
                      Text(
                        '100%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '150%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '200%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '250%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '300%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ]
                  : [
                      Text(
                        '100%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '120%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '140%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '160%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
            ),
            const SizedBox(height: 12),
            Text(
              '用于达标后工时统计和目标进度的颜色判断',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// 打卡提醒设置卡片
  Widget _buildPunchReminderSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上班提醒
            Row(
              children: [
                Icon(Icons.wb_sunny, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '上班打卡提醒',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _morningReminderEnabled,
                  onChanged: (value) => _toggleMorningReminder(value),
                  activeThumbColor: Colors.orange[700],
                ),
              ],
            ),
            if (_morningReminderEnabled) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectReminderTime(true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(_morningReminderTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 24),
            // 下班提醒
            Row(
              children: [
                Icon(Icons.nightlight, size: 20, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '下班打卡提醒',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _eveningReminderEnabled,
                  onChanged: (value) => _toggleEveningReminder(value),
                  activeThumbColor: Colors.indigo[700],
                ),
              ],
            ),
            if (_eveningReminderEnabled) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectReminderTime(false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.indigo[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(_eveningReminderTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 24),
            // 功能按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPermissionGuide,
                    icon: const Icon(Icons.settings_suggest, size: 18),
                    label: const Text('权限设置'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_morningReminderEnabled || _eveningReminderEnabled)
                        ? _testReminder
                        : null,
                    icon: const Icon(Icons.bug_report, size: 18),
                    label: const Text('测试生效'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '需开启自启动、关闭省电优化才能正常提醒',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换上班提醒
  Future<void> _toggleMorningReminder(bool enabled) async {
    HapticUtils.selectionClick();

    final result = await _reminderCoordinator.setMorningReminder(
      enabled: enabled,
      hour: _morningReminderTime.hour,
      minute: _morningReminderTime.minute,
    );

    await _applyReminderToggleResult(
      result,
      isMorning: true,
      requestedEnabled: enabled,
      showGuideOnEnabled: true,
    );
  }

  /// 切换下班提醒
  Future<void> _toggleEveningReminder(bool enabled) async {
    HapticUtils.selectionClick();

    final result = await _reminderCoordinator.setEveningReminder(
      enabled: enabled,
      hour: _eveningReminderTime.hour,
      minute: _eveningReminderTime.minute,
    );

    await _applyReminderToggleResult(
      result,
      isMorning: false,
      requestedEnabled: enabled,
      showGuideOnEnabled: true,
    );
  }

  Future<void> _rescheduleReminderAfterTimeChange({
    required bool isMorning,
    required TimeOfDay time,
  }) async {
    final result = isMorning
        ? await _reminderCoordinator.setMorningReminder(
            enabled: true,
            hour: time.hour,
            minute: time.minute,
          )
        : await _reminderCoordinator.setEveningReminder(
            enabled: true,
            hour: time.hour,
            minute: time.minute,
          );

    await _applyReminderToggleResult(
      result,
      isMorning: isMorning,
      requestedEnabled: true,
      showGuideOnEnabled: false,
    );
  }

  Future<void> _applyReminderToggleResult(
    ReminderToggleResult result, {
    required bool isMorning,
    required bool requestedEnabled,
    required bool showGuideOnEnabled,
  }) async {
    if (!mounted) return;

    switch (result) {
      case ReminderToggleResult.enabled:
        setState(() {
          if (isMorning) {
            _morningReminderEnabled = true;
          } else {
            _eveningReminderEnabled = true;
          }
        });
        if (requestedEnabled && showGuideOnEnabled) {
          _showFirstTimeGuideDialog();
        }
        return;
      case ReminderToggleResult.disabled:
        setState(() {
          if (isMorning) {
            _morningReminderEnabled = false;
          } else {
            _eveningReminderEnabled = false;
          }
        });
        return;
      case ReminderToggleResult.notificationPermissionDenied:
        await _disableReminderAfterPermissionDenied(isMorning);
        if (!mounted) return;
        _showReminderPermissionSnackBar('需要通知权限才能提醒');
        return;
      case ReminderToggleResult.exactAlarmPermissionDenied:
        await _disableReminderAfterPermissionDenied(isMorning);
        if (!mounted) return;
        _showReminderPermissionSnackBar('需要允许精确闹钟权限才能准时提醒');
        return;
    }
  }

  Future<void> _disableReminderAfterPermissionDenied(bool isMorning) async {
    if (isMorning) {
      await _settingsRepository.saveReminderTime(
        isMorning: true,
        enabled: false,
        hour: _morningReminderTime.hour,
        minute: _morningReminderTime.minute,
      );
    } else {
      await _settingsRepository.saveReminderTime(
        isMorning: false,
        enabled: false,
        hour: _eveningReminderTime.hour,
        minute: _eveningReminderTime.minute,
      );
    }

    if (!mounted) return;
    setState(() {
      if (isMorning) {
        _morningReminderEnabled = false;
      } else {
        _eveningReminderEnabled = false;
      }
    });
  }

  void _showReminderPermissionSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// 选择提醒时间
  Future<void> _selectReminderTime(bool isMorning) async {
    final initialTime = isMorning ? _morningReminderTime : _eveningReminderTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      HapticUtils.selectionClick();

      if (isMorning) {
        setState(() => _morningReminderTime = picked);
        if (_morningReminderEnabled) {
          await _rescheduleReminderAfterTimeChange(
            isMorning: true,
            time: picked,
          );
        } else {
          await _settingsRepository.saveReminderTime(
            isMorning: true,
            enabled: false,
            hour: picked.hour,
            minute: picked.minute,
          );
        }
      } else {
        setState(() => _eveningReminderTime = picked);
        if (_eveningReminderEnabled) {
          await _rescheduleReminderAfterTimeChange(
            isMorning: false,
            time: picked,
          );
        } else {
          await _settingsRepository.saveReminderTime(
            isMorning: false,
            enabled: false,
            hour: picked.hour,
            minute: picked.minute,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isMorning ? '上班' : '下班'}提醒时间已设置为 ${_formatTime(picked)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 显示权限设置指南
  void _showPermissionGuide() {
    HapticUtils.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhonePermissionGuide()),
    );
  }

  /// 首次开启提示
  void _showFirstTimeGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.orange),
            SizedBox(width: 8),
            Text('重要提示'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '为确保提醒正常工作，请务必：\n\n'
                '1. 开启应用自启动权限\n'
                '2. 关闭省电优化/电池优化\n'
                '3. 在后台锁定本应用\n\n'
                '点击"查看设置"获取详细指南',
              ),
              const SizedBox(height: 16),
              // 实验性功能警告
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 6),
                        Text(
                          '实验性功能',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '此功能采用本地闹钟而非服务器推送，在国产手机（小米/华为/OPPO/vivo等）上可能因后台管理被系统限制。\n\n'
                      '如按指南设置后仍无法收到提醒，建议使用手机自带闹钟作为备选方案。',
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后设置'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPermissionGuide();
            },
            child: const Text('查看设置'),
          ),
        ],
      ),
    );
  }

  /// 测试提醒功能
  Future<void> _testReminder() async {
    HapticUtils.mediumImpact();

    // 显示倒计时对话框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TestCountdownDialog(),
    );

    if (confirmed == true && mounted) {
      // 设置10秒后的测试闹钟
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.scheduleTestAlarm();

      // 退出APP
      exit(0);
    }
  }

  /// 智能排序设置卡片
  Widget _buildSmartSortSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sort, size: 20, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '智能排序',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _smartSort,
                  onChanged: (value) async {
                    await HapticUtils.selectionClick();
                    setState(() => _smartSort = value);
                    await _settingsRepository.saveSmartSort(value);
                  },
                  activeThumbColor: Colors.purple[700],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _smartSort ? '开启：最高达成 → 即将达成 → 其他(升序)' : '关闭：全部按目标从低到高排序',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '置顶目标始终显示在最前面',
                      style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 震动反馈设置卡片
  Widget _buildHapticSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vibration, size: 20, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '震动模式',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 三个选项
            _buildHapticOption(
              mode: HapticMode.advanced,
              icon: Icons.auto_awesome,
              title: '高级',
              subtitle: '线性马达专属，丰富细腻的触感体验',
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            _buildHapticOption(
              mode: HapticMode.basic,
              icon: Icons.touch_app,
              title: '基础',
              subtitle: '适用于转子马达，简化的震动反馈',
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildHapticOption(
              mode: HapticMode.off,
              icon: Icons.do_not_disturb,
              title: '关闭',
              subtitle: '不使用震动反馈',
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.teal[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '高级模式包含下拉蓄力、释放爆发、边界碰撞等特效',
                      style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 震动选项
  Widget _buildHapticOption({
    required HapticMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
  }) {
    final isSelected = _hapticMode == mode;

    return InkWell(
      onTap: () async {
        await HapticUtils.setMode(mode);
        // 立即体验新模式的震动
        if (mode != HapticMode.off) {
          await HapticUtils.mediumImpact();
        }
        setState(() => _hapticMode = mode);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color[400]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? color[700] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color[700] : Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color[600], size: 22),
          ],
        ),
      ),
    );
  }

  /// 午休时间设置卡片
  Widget _buildLunchTimeSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  '午休时间',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '工时计算时，跨越午休时间段会自动扣除',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    label: '开始时间',
                    time: _lunchStartTime,
                    onTap: () async {
                      await HapticUtils.selectionClick();
                      await _selectTime(true);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward, color: Colors.grey[400]),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeSelector(
                    label: '结束时间',
                    time: _lunchEndTime,
                    onTap: () async {
                      await HapticUtils.selectionClick();
                      await _selectTime(false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '午休时长: ${_calculateLunchDuration()}分钟',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 跨天时间点设置卡片
  Widget _buildCrossDaySettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nights_stay, size: 20, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                const Text(
                  '跨天时间点',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '凌晨下班时，该时间前视为"昨天"的工作日',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectCrossDayTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: Colors.indigo[600],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(_crossDayTime),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.edit, size: 18, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.amber[800],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '例：凌晨0:10下班，未超04:00算作前一天',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择跨天时间点
  Future<void> _selectCrossDayTime() async {
    await HapticUtils.selectionClick();
    if (!mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _crossDayTime,
      helpText: '选择跨天时间点',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    // 限制在 00:00 - 06:00 之间
    if (picked.hour > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('跨天时间点只可设置在00:00-06:00之间'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _crossDayTime = picked;
    });

    await DateHelper.setCrossDayTime(picked);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('跨天时间点已设置为 ${_formatTime(picked)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 时间选择器
  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 计算午休时长
  int _calculateLunchDuration() {
    final startMinutes = _lunchStartTime.hour * 60 + _lunchStartTime.minute;
    final endMinutes = _lunchEndTime.hour * 60 + _lunchEndTime.minute;
    return endMinutes - startMinutes;
  }

  /// 账号管理设置卡片
  Widget _buildAccountSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息显示
            if (_userName != null || _teamName != null) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_userName != null)
                          Text(
                            _userName!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (_teamName != null)
                          Text(
                            _teamName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _switchTeam,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('切换团队'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      '退出登录',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 帮助与反馈设置卡片
  Widget _buildHelpSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能说明
            InkWell(
              onTap: _openFeatureGuide,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: Colors.blue[700],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '功能说明',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '了解App的各项功能和使用方法',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            // 重新体验引导
            InkWell(
              onTap: _restartOnboarding,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.replay,
                        color: Colors.orange[700],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '重新体验新手引导',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '再次查看下拉刷新等操作引导',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开功能说明页面
  void _openFeatureGuide() {
    HapticUtils.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeatureGuidePage()),
    );
  }

  /// 重新体验新手引导
  Future<void> _restartOnboarding() async {
    HapticUtils.lightImpact();

    await _settingsRepository.saveOnboardingCompleted(false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置，重启本应用，即可重新体验新手引导'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 切换团队
  Future<void> _switchTeam() async {
    HapticUtils.lightImpact();

    if (_apiClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final teamContextService = TeamContextService(
        storage: _storage,
        loadAccountDetail: _apiClient!.getAccountDetail,
        changeTeam: _apiClient!.changeTeam,
      );
      final teamInfoList = await teamContextService.loadTeams();

      // 显示团队选择对话框
      final selectedTeam = await _showTeamSelectionDialog(teamInfoList);
      if (selectedTeam == null) {
        // 用户取消选择
        return;
      }

      final teamContext = await teamContextService.switchTo(selectedTeam);
      if (!teamContext.teamChanged) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已经是当前团队')));
        }
        return;
      }

      // 更新本地状态
      setState(() {
        _teamNo = teamContext.teamNo;
        _teamName = teamContext.teamName;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已切换到: ${teamContext.teamName}')));

      final token = await _settingsRepository.loadToken() ?? '';
      if (!mounted) return;

      // 返回主页并刷新数据（直接到MainScreen，不经过LoginScreen）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainScreen(token: token)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换团队失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 显示团队选择对话框
  Future<Map<String, dynamic>?> _showTeamSelectionDialog(
    List<dynamic> teams,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择团队'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index] as Map<String, dynamic>;
                final teamName = team['teamName'] as String? ?? '未知团队';
                final teamNo = team['teamNo'] as String?;
                final isCurrentTeam = teamNo != null && teamNo == _teamNo;
                return ListTile(
                  title: Text(teamName),
                  trailing: isCurrentTeam
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    HapticUtils.selectionClick();
                    Navigator.of(context).pop(team);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 退出登录
  Future<void> _logout() async {
    HapticUtils.lightImpact();

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _sessionService.logout();

    if (mounted) {
      // 跳转到登录页（使用 forceLogout 确保 WebView 也清除 cookies）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(forceLogout: true)),
        (route) => false,
      );
    }
  }

  /// 调试工具标题（带开关）
  Widget _buildDebugToolsHeader() {
    return Row(
      children: [
        Icon(Icons.developer_mode, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '开发者工具',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        Switch(
          value: _debugToolsEnabled,
          onChanged: (value) async {
            HapticUtils.lightImpact();
            setState(() => _debugToolsEnabled = value);
            await _settingsRepository.saveDebugToolsEnabled(value);
          },
          activeThumbColor: Colors.red,
        ),
      ],
    );
  }

  /// 开发者选项设置卡片
  Widget _buildDeveloperSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, size: 20, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text(
                  '调试工具',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '仅供开发测试使用，请谨慎操作',
              style: TextStyle(fontSize: 12, color: Colors.red[400]),
            ),
            const SizedBox(height: 16),
            // 生成无效Token按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateInvalidToken,
                icon: Icon(Icons.vpn_key_off, color: Colors.red[700]),
                label: Text(
                  '生成无效Token',
                  style: TextStyle(color: Colors.red[700]),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.red[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '替换当前Token为无效值，测试Token过期后的流程',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // 复制Token按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyCurrentToken,
                icon: Icon(Icons.content_copy, color: Colors.blue[700]),
                label: Text(
                  '复制当前Token',
                  style: TextStyle(color: Colors.blue[700]),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.blue[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '复制Token到剪贴板，用于API调试',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

    /// 复制当前Token
  Future<void> _copyCurrentToken() async {
    HapticUtils.lightImpact();
    final token = await _settingsRepository.loadToken() ?? '';

    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token为空'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制 (${token.length}字符)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// 生成无效Token
  Future<void> _generateInvalidToken() async {
    HapticUtils.lightImpact();

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('确认操作'),
          ],
        ),
        content: const Text(
          '此操作将：\n\n'
          '1. 先用当前有效Token调用logout接口\n'
          '2. 清除海康WebView的登录状态\n'
          '3. 将Token替换为无效值\n'
          '4. 需要重新登录才能恢复\n\n'
          '确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认生成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 获取当前token
      final currentToken = await _settingsRepository.loadToken() ?? '';
      final shortToken = currentToken.length > 20
          ? '${currentToken.substring(0, 20)}...'
          : currentToken;

      await _sessionService.clearRemoteAndWebSession(currentToken);

      // 生成无效token
      const invalidToken = 'INVALID_TOKEN_FOR_DEBUG_TESTING_12345';

      // 替换token
      await _settingsRepository.saveTokenForDebug(invalidToken);

      if (mounted) {
        // 显示成功提示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text('Token已替换'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '原Token:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(shortToken, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Text(
                  '新Token:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Text(
                  'INVALID_TOKEN_FOR_DEBUG...',
                  style: TextStyle(fontSize: 13, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '返回主页后刷新数据即可触发Token失效流程',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 返回主页
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => MainScreen(token: invalidToken),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('返回主页'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// 测试倒计时对话框
class _TestCountdownDialog extends StatefulWidget {
  @override
  State<_TestCountdownDialog> createState() => _TestCountdownDialogState();
}

class _TestCountdownDialogState extends State<_TestCountdownDialog> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.timer, color: Colors.teal),
          SizedBox(width: 8),
          Text('测试提醒'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '即将关闭应用并在10秒后发送测试通知\n\n'
            '请确保：\n'
            '• 应用已被完全关闭（杀后台）\n'
            '• 手机未开启勿扰模式',
          ),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                '$_countdown',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          child: const Text('取消'),
        ),
      ],
    );
  }
}
