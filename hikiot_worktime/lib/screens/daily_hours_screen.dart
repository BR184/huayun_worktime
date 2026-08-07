import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../core/constants/constants.dart';
import '../core/theme/theme.dart';
import '../services/daily_attendance_repository.dart';
import '../services/storage_service.dart';
import '../services/token_expired_service.dart';
import '../utils/work_time_calculator.dart';
import '../utils/best_clockout_planner.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_helper.dart';
import '../utils/target_progress_helper.dart';
import '../widgets/best_clock_out_entry.dart';
import '../widgets/haptic_refresh_indicator.dart';
import '../widgets/precision_text.dart';
import '../widgets/pull_refresh_guide.dart';
import 'best_clock_out_detail_screen.dart';
import 'feature_guide_page.dart';
import 'photo_preview_screen.dart';

class DailyHoursScreen extends StatefulWidget {
  final bool autoLoad;

  const DailyHoursScreen({super.key, this.autoLoad = true});

  @override
  DailyHoursScreenState createState() => DailyHoursScreenState();
}

class DailyHoursScreenState extends State<DailyHoursScreen>
    with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  late final DailyAttendanceRepository _dailyRepository;
  DateTime _selectedDate = DateHelper.getWorkDate();
  Map<String, dynamic>? _dayData;
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = false;
  String? _loadError; // 加载失败提示（如缺少员工编号），非空时显示错误视图
  String? _teamNo;
  Map<String, String> _holidayPlan = {}; // 节假日计划
  bool _useCheckInTime = true; // 默认使用打卡时间计算
  int? _pinnedTarget; // 置顶的目标
  bool _smartSort = true; // 智能排序开关
  int _baseTarget = 120; // 基础目标百分比
  bool _showOnboarding = false; // 是否显示新手引导
  bool _isUserPullRefresh = false; // 是否是用户主动下拉刷新
  String _commuteMode = 'free'; // 通勤方式（free/metro/bus）
  int _commuteMetroDirection = 0; // 地铁方向下标
  int _commuteMetroWalkMinutes = 7; // 到地铁站步行分钟

  /// 加载通勤设置（出行方式 + 地铁方向 + 步行分钟）
  Future<void> _loadCommuteSettings() async {
    final mode = await _storage.loadCommuteMode();
    final direction = await _storage.loadCommuteMetroDirection();
    final walkMinutes = await _storage.loadCommuteMetroWalkMinutes();
    if (mounted) {
      setState(() {
        _commuteMode = mode;
        _commuteMetroDirection = direction;
        _commuteMetroWalkMinutes = walkMinutes;
      });
    }
  }

  /// 详情页返回后刷新通勤设置
  Future<void> _reloadCommuteMode() async {
    await _loadCommuteSettings();
  }

  @override
  void initState() {
    super.initState();
    _dailyRepository = DailyAttendanceRepository(storage: _storage);
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('zh_CN', null);
    _loadPinnedTarget();
    _loadSmartSort();
    _loadCommuteSettings();
    if (widget.autoLoad) {
      _loadDailyData();
    }
    _checkAndShowOnboarding(); // 检查新手引导
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSmartSort();
      _loadDailyData();
    }
  }

  /// 检查并显示新手引导
  Future<void> _checkAndShowOnboarding() async {
    // 检查是否首次使用
    final completed = await _storage.loadOnboardingCompleted();

    if (!completed) {
      // 延迟显示，让用户先看到页面内容
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showOnboarding = true;
        });
      }
    }
  }

  /// 显示新手引导(供外部调用)
  void showOnboarding() {
    setState(() {
      _showOnboarding = true;
    });
  }

  /// 完成新手引导
  Future<void> _completeOnboarding() async {
    setState(() {
      _showOnboarding = false;
    });

    // 标记引导已完成
    await _storage.saveOnboardingCompleted(true);

    // 显示恭喜动画
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CongratulationsDialog(
        onContinue: () {
          Navigator.of(context).pop();
          // 打开功能说明页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FeatureGuidePage(showCloseButton: true),
            ),
          );
        },
      ),
    );
  }

  /// 加载置顶目标
  Future<void> _loadPinnedTarget() async {
    final target = await _storage.loadPinnedTarget();
    if (mounted) {
      setState(() {
        _pinnedTarget = target;
      });
    }
  }

  /// 加载智能排序开关
  Future<void> _loadSmartSort() async {
    final enabled = await _storage.loadSmartSort();
    if (mounted) {
      setState(() {
        _smartSort = enabled;
      });
    }
  }

  /// 切换置顶目标
  Future<void> _togglePinnedTarget(int target) async {
    final newTarget = WorkTimeCalculator.calculateNewPinnedTarget(
      _pinnedTarget,
      target,
    );
    await _storage.savePinnedTarget(newTarget);
    setState(() {
      _pinnedTarget = newTarget;
    });
  }

  /// 公开方法:从其他页面切换回来时刷新数据
  Future<void> refreshData() async {
    await _loadSmartSort();
    // 重新加载所有数据（包括手动标记），确保与月度页面的修改同步
    await _loadDailyData();
  }

  DateTime get selectedDate => _selectedDate;

  /// 加载每日数据
  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);

    try {
      final result = await _dailyRepository.load(_selectedDate);
      if (!mounted) return;

      _smartSort = result.smartSort;
      _pinnedTarget = result.pinnedTarget;
      _baseTarget = result.baseTarget;
      _teamNo = result.teamNo;
      _holidayPlan = result.holidayPlan;
      _dayData = result.dayData.isEmpty ? null : result.dayData;
      _attendanceData = result.attendanceData;
      _loadError = null;

      if (result.status == DailyAttendanceLoadStatus.missingToken) {
        await TokenExpiredService.handleTokenExpired(context);
        return;
      }

      if (result.status == DailyAttendanceLoadStatus.missingPersonNo) {
        // 缺少员工编号：不能静默显示空工时，需重新登录初始化团队上下文
        setState(() {
          _loadError = '未找到员工编号，团队上下文可能已失效，请重新登录';
          _dayData = null;
          _attendanceData = null;
        });
        return;
      }

      // 如果正在显示引导且是用户主动下拉刷新，完成引导
      if (_showOnboarding && _isUserPullRefresh) {
        _isUserPullRefresh = false;
        _completeOnboarding();
      }
    } catch (e) {
      if (mounted && TokenExpiredService.isTokenExpiredError(e)) {
        await TokenExpiredService.handleTokenExpired(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '刷新失败: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 计算工时
  double _calculateHours() {
    final type = _dayData?['type'] ?? AppConstants.typeWorkday;

    // 如果是自定义类型 或 (出差且自定义工时), 从dayData获取工时
    if ((type == AppConstants.typeCustom ||
            (type == AppConstants.typeBusinessTrip &&
                _dayData?['isCustomHours'] == true)) &&
        _dayData != null) {
      final hours = _dayData!['hours'];
      if (hours is double) return hours;
      if (hours is int) return hours.toDouble();
    }

    // 出差默认8小时
    if (type == AppConstants.typeBusinessTrip) {
      return 8.0;
    }

    // 其他情况从考勤数据计算工时
    if (_attendanceData != null) {
      final checkIn = _attendanceData!['checkInTime'] as String?;
      final checkOut = _attendanceData!['checkOutTime'] as String?;

      if (checkIn != null && checkOut != null) {
        // 使用统一的工时计算工具类
        return WorkTimeCalculator.calculateWorkHoursStr(checkIn, checkOut);
      }
    }

    return 0.0;
  }

  /// 根据当前手机时间计算工时(用于目标进度开关关闭时)
  double _calculateCurrentHoursFromNow(String checkIn) {
    final checkInMinutes = WorkTimeCalculator.parseTimeToMinutes(checkIn);
    if (checkInMinutes == null) return 0.0;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // 使用统一的工时计算工具类
    return WorkTimeCalculator.calculateWorkHours(
      checkInMinutes,
      currentMinutes,
    );
  }

  /// 选择日期
  Future<void> _selectDate() async {
    HapticUtils.lightImpact(); // 打开日期选择器时震动
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: AppConstants.earliestDate,
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedDate) {
      HapticUtils.selectionClick(); // 选择了新日期时震动
      setState(() {
        _selectedDate = picked;
        _dayData = null;
        _attendanceData = null;
      });
      await _loadDailyData();
    }
  }

  /// 修改类型/工时
  Future<void> _showEditDialog() async {
    final type = _dayData?['type'] ?? AppConstants.typeWorkday;

    // 没有打卡的休息日不能改为请假/加班/工作
    final hasAttendance = _attendanceData?['checkInTime'] != null;
    final isRest = type == AppConstants.typeRestDay || type == '休息';
    final isManual = _dayData?['isManual'] ?? false;

    await showDialog(
      context: context,
      builder: (_) => _EditDayDialog(
        date: _selectedDate,
        initialData: _dayData,
        attendanceData: _attendanceData,
        canModify: !(isRest && !hasAttendance),
        onSave: (newData) async {
          final result = await _dailyRepository.saveManualMark(
            selectedDate: _selectedDate,
            markData: newData,
            teamNo: _teamNo,
          );
          if (result == null || !mounted) return;

          setState(() {
            _teamNo = result.teamNo;
            _dayData = result.dayData;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('保存成功')));
        },
        onRestore: isManual
            ? () async {
                final result = await _dailyRepository.restoreDefaultMark(
                  selectedDate: _selectedDate,
                  currentData: _dayData ?? <String, dynamic>{},
                  holidayPlan: _holidayPlan,
                  attendanceData: _attendanceData,
                  teamNo: _teamNo,
                );
                if (result == null || !mounted) return;

                setState(() {
                  _teamNo = result.teamNo;
                  _dayData = result.dayData;
                });

                final defaultType = result.dayData['type'] as String? ?? '';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已恢复为默认类型: $defaultType')),
                );
              }
            : null,
      ),
    );
  }

  /// 显示打卡照片弹窗
  void _showPhotoDialog() {
    final checkInPhotoUrl = _attendanceData?['checkInPhotoUrl'] as String?;
    final checkOutPhotoUrl = _attendanceData?['checkOutPhotoUrl'] as String?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '打卡照片',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (checkInPhotoUrl != null) ...[
                const Text(
                  '上班打卡',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildPhotoWidget(checkInPhotoUrl, 'checkIn'),
                const SizedBox(height: 16),
              ],
              if (checkOutPhotoUrl != null) ...[
                const Text(
                  '下班打卡',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildPhotoWidget(checkOutPhotoUrl, 'checkOut'),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建照片组件
  Widget _buildPhotoWidget(String photoUrl, String label) {
    // 使用URL作为Hero Tag，保证唯一性
    final heroTag = 'photo_$label$photoUrl';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PhotoPreviewScreen(photoUrl: photoUrl, heroTag: heroTag),
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            photoUrl,
            height: 200,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 150,
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('照片加载失败', style: TextStyle(color: Colors.grey)),
                  // 移除详细错误显示，保持界面整洁(KISS)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = _calculateHours();
    final type = _dayData?['type'] ?? AppConstants.typeWorkday;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('每日工时'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading
                    ? null
                    : () async {
                        await HapticUtils.lightImpact();
                        _loadDailyData();
                      },
                tooltip: '刷新',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildLoadErrorView()
              : HapticRefreshIndicator(
                  onRefresh: () async {
                    _isUserPullRefresh = true; // 标记为用户主动下拉
                    await _loadDailyData();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateSelector(),
                        const SizedBox(height: 12),
                        // 最佳下班时间入口：醒目位置，颜色即状态
                        _buildBestClockOutBanner(),
                        const SizedBox(height: 12),
                        _buildTypeWarning(type),
                        const SizedBox(height: 12),
                        if (_hasCrossDayPunch) ...[
                          _buildCrossDayPunchReminder(),
                          const SizedBox(height: 12),
                        ],
                        _buildActionButtons(),
                        const SizedBox(height: 12),
                        _buildHoursCard(hours, type),
                        const SizedBox(height: 12),
                        _buildTargetProgress(hours),
                      ],
                    ),
                  ),
                ),
        ),
        // 新手引导覆盖层
        if (_showOnboarding) PullRefreshGuide(onCompleted: _completeOnboarding),
      ],
    );
  }

  /// 加载失败视图（如缺少员工编号），提供重试与重新登录入口
  Widget _buildLoadErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _loadDailyData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () =>
                      TokenExpiredService.performLogoutAndNavigate(context),
                  icon: const Icon(Icons.login),
                  label: const Text('重新登录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasCrossDayPunch =>
      _attendanceData?['hasCrossDayPunch'] == true ||
      _dayData?['hasCrossDayPunch'] == true;

  String? get _crossDayPunchTime =>
      _attendanceData?['crossDayPunchTime'] as String? ??
      _dayData?['crossDayPunchTime'] as String?;

  Widget _buildDateSelector() {
    final isToday = _isToday();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await HapticUtils.selectionClick();
                  _selectDate();
                },
                child: Text(
                  DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            if (!isToday)
              TextButton.icon(
                onPressed: () async {
                  await HapticUtils.selectionClick();
                  setState(() {
                    _selectedDate = DateHelper.getWorkDate();
                    _dayData = null;
                    _attendanceData = null;
                  });
                  await _loadDailyData();
                },
                icon: const Icon(Icons.today, size: 18),
                label: const Text('今日'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppColors.primaryDark,
              ),
              onPressed: () async {
                await HapticUtils.selectionClick();
                _selectDate();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 类型提示警告（放在顶部）
  Widget _buildTypeWarning(String type) {
    final isManual = _dayData?['isManual'] ?? false;

    // 获取类型颜色
    final typeColor = AppColors.getTypeColor(type);
    IconData typeIcon;
    String? warningText;

    switch (type) {
      case '工作日':
        typeIcon = Icons.work;
        break;
      case '加班日':
        typeIcon = Icons.more_time;
        break;
      case '出差':
        typeIcon = Icons.flight_takeoff;
        warningText = '出差固定计 8 小时工时';
        break;
      case '请假':
        typeIcon = Icons.event_busy;
        warningText = '请假统计工时为 0，如需统计请改为 工作日 或 自定义 类型';
        break;
      case '自定义':
        typeIcon = Icons.tune;
        break;
      case '非工作日':
        typeIcon = Icons.weekend;
        break;
      default:
        typeIcon = Icons.help_outline;
    }

    // 检查是否有照片
    final hasPhoto =
        _attendanceData?['checkInPhotoUrl'] != null ||
        _attendanceData?['checkOutPhotoUrl'] != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warningText != null
            ? typeColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: warningText != null
            ? Border.all(color: typeColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isManual
                      ? AppColors.warningLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isManual ? '手动' : '自动',
                  style: TextStyle(
                    fontSize: 10,
                    color: isManual ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
              const Spacer(),
              // 查看照片按钮
              if (hasPhoto)
                GestureDetector(
                  onTap: () => _showPhotoDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '查看打卡照片',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (warningText != null) ...[
            const SizedBox(height: 6),
            Text(
              warningText,
              style: TextStyle(
                fontSize: 11,
                color: typeColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrossDayPunchReminder() {
    final punchTime = _crossDayPunchTime ?? '凌晨';
    final cutoffTime = DateHelper.getCrossDayTimeString();

    return Card(
      color: AppColors.warningLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.nights_stay, color: AppColors.warningDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '检测到跨天打卡',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warningDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '检测到 $punchTime 的打卡记录，位于 00:00-$cutoffTime 提醒窗口内。海康接口按自然日返回，无法自动并入上一日工时，请手动设置对应日期工时。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.warningDark,
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

  Widget _buildHoursCard(double hours, String type) {
    final showsPercentage =
        type != AppConstants.typeOvertime &&
        type != AppConstants.typeRestDay &&
        type != '休息';
    final percentage = WorkTimeCalculator.calculatePercentage(
      hours: hours,
      baseHours: 8,
    );

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '今日打卡工时',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      type,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PrecisionText(
                            WorkTimeCalculator.formatHours(hours),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 6, bottom: 3),
                            child: Text(
                              '小时',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showsPercentage) ...[
                      Container(
                        width: 1,
                        height: 42,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: AppColors.divider,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '完成率',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          PrecisionText(
                            '${WorkTimeCalculator.formatHours(percentage)}%',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckInOutCard(),
        // 自定义类型显示设置的时间
        if (type == AppConstants.typeCustom) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppDimens.borderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自定义工时时间',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dayData?['customCheckIn'] ?? '09:00'} - ${_dayData?['customCheckOut'] ?? '18:00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 上下班打卡时间卡片
  Widget _buildCheckInOutCard() {
    final checkIn = _attendanceData?['checkInTime'] as String?;
    final checkOut = _attendanceData?['checkOutTime'] as String?;

    if (checkIn == null) {
      return const SizedBox.shrink();
    }

    // 判断是否是今天
    final isToday = _isToday();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.login, color: AppColors.success, size: 20),
                      const SizedBox(height: 8),
                      const Text(
                        '上班打卡',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkIn,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.logout,
                        color: checkOut != null
                            ? AppColors.warning
                            : Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '下班打卡',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkOut ?? '未打卡',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: checkOut != null
                              ? AppColors.warning
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 仅今日显示实时工时信息
        if (isToday) ...[
          const SizedBox(height: 12),
          _buildRealtimeHoursInfo(checkIn, checkOut),
        ],
      ],
    );
  }

  /// 构建实时工时信息(仅今日)
  Widget _buildRealtimeHoursInfo(String checkIn, String? checkOut) {
    final checkInMinutes = WorkTimeCalculator.parseTimeToMinutes(checkIn);
    if (checkInMinutes == null) return const SizedBox.shrink();

    // 信息1: 按照实际打卡时间计算当前工时
    double actualHours = 0.0;
    if (checkOut != null && checkOut.isNotEmpty) {
      actualHours = WorkTimeCalculator.calculateWorkHoursStr(checkIn, checkOut);
    }

    // 信息2: 如果现在下班的预估工时
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final estimatedHours = WorkTimeCalculator.calculateWorkHours(
      checkInMinutes,
      currentMinutes,
    );

    // 截断到2位小数(不四舍五入)
    // 使用 formatHours 统一处理

    final actualPercentageRaw = WorkTimeCalculator.calculatePercentage(
      hours: actualHours,
      baseHours: 8,
      min: 0,
      max: 200,
    );

    final estimatedPercentageRaw = WorkTimeCalculator.calculatePercentage(
      hours: estimatedHours,
      baseHours: 8,
      min: 0,
      max: 200,
    );

    Color getPercentageColor(double percentage) {
      if (percentage >= _baseTarget) return AppColors.success;
      if (percentage >= 100) return AppColors.warning;
      return AppColors.primary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 信息1: 实际打卡工时
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                const Text(
                  '按照打卡时间',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                PrecisionText(
                  '工时: ${WorkTimeCalculator.formatHours(actualHours)}h',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(actualPercentageRaw),
                  ),
                ),
                const SizedBox(width: 12),
                PrecisionText(
                  '${WorkTimeCalculator.formatHours(actualPercentageRaw)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(actualPercentageRaw),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 信息2: 现在下班的预估工时
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 20,
                  color: AppColors.overtime,
                ),
                const SizedBox(width: 8),
                const Text(
                  '如果现在下班',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                PrecisionText(
                  '工时: ${WorkTimeCalculator.formatHours(estimatedHours)}h',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(estimatedPercentageRaw),
                  ),
                ),
                const SizedBox(width: 12),
                PrecisionText(
                  '${WorkTimeCalculator.formatHours(estimatedPercentageRaw)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(estimatedPercentageRaw),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 最佳下班时间入口（醒目横幅，仅今日显示，内部实时刷新）。
  ///
  /// 颜色即状态：绿=现在下班最佳；琥珀=一般；红=浪费较多；灰=未打卡。
  /// 有打卡记录即按当前时刻计算（公司打卡机进出频繁，
  /// 最后一次打卡不代表已下班，不做"已下班"判断）。
  Widget _buildBestClockOutBanner() {
    if (!_isToday()) return const SizedBox.shrink();

    final checkIn = _attendanceData?['checkInTime'] as String?;
    final checkInMinutes = checkIn == null || checkIn.isEmpty
        ? null
        : WorkTimeCalculator.parseTimeToMinutes(checkIn);
    final mode = CommuteMode.values.firstWhere(
      (m) => m.name == _commuteMode,
      orElse: () => CommuteMode.free,
    );

    return BestClockOutBanner(
      checkInMinutes: checkInMinutes,
      mode: mode,
      metroDirection: _commuteMetroDirection,
      metroWalkMinutes: _commuteMetroWalkMinutes,
      onTap: _openBestClockOutDetail,
    );
  }

  /// 打开最佳下班时间详情页，返回后刷新本地通勤设置
  void _openBestClockOutDetail() {
    HapticUtils.lightImpact();
    final checkIn = _attendanceData?['checkInTime'] as String?;
    final checkInMinutes = checkIn == null || checkIn.isEmpty
        ? null
        : WorkTimeCalculator.parseTimeToMinutes(checkIn);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BestClockOutDetailScreen(checkInMinutes: checkInMinutes),
      ),
    ).then((_) => _reloadCommuteMode());
  }

  /// 构建历史统计信息(用于过去的日期)
  Widget _buildHistoricalStats(double hours, String type) {
    final checkIn = _attendanceData?['checkInTime'] as String?;
    final checkOut = _attendanceData?['checkOutTime'] as String?;

    // 计算工时完成率：计入工时与结果都截断到一位小数。
    final completionRaw = WorkTimeCalculator.calculatePercentage(
      hours: hours,
      baseHours: 8,
      min: 0,
      max: 200,
    );

    // 计算上班时长(如果有打卡记录)
    String workDuration = '--';
    if (checkIn != null && checkOut != null) {
      try {
        final inParts = checkIn.split(':');
        final outParts = checkOut.split(':');
        final inMinutes = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
        final outMinutes = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
        final totalMinutes = outMinutes - inMinutes;
        final totalHours = totalMinutes / 60;
        // 截断到2位小数
        workDuration = '${WorkTimeCalculator.formatHours(totalHours)}小时';
      } catch (e) {
        workDuration = '--';
      }
    }

    Color getCompletionColor() {
      if (completionRaw >= 100) return AppColors.success;
      if (completionRaw >= 80) return AppColors.warning;
      return AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.assessment_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              '当日统计',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 工时完成率
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '工时完成率',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    PrecisionText(
                      '${WorkTimeCalculator.formatHours(completionRaw)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: getCompletionColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (completionRaw / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    getCompletionColor(),
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // 详细统计
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '实际工时',
                        '${WorkTimeCalculator.formatHours(hours)}h',
                        Icons.access_time,
                        AppColors.primary,
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.grey[300]),
                    Expanded(
                      child: _buildStatItem(
                        '上班时长',
                        workDuration,
                        Icons.timer,
                        AppColors.overtime,
                      ),
                    ),
                  ],
                ),
                if (type == AppConstants.typeBusinessTrip) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight_takeoff,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '出差类型(固定8小时)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (type == AppConstants.typeCustom) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '自定义: ${_dayData?['customCheckIn'] ?? '09:00'} - ${_dayData?['customCheckOut'] ?? '18:00'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        PrecisionText(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 目标进度(仿照每月样式) 或 历史统计
  Widget _buildTargetProgress(double hours) {
    final type = _dayData?['type'] ?? AppConstants.typeWorkday;

    // 加班日、非工作日、请假、出差 不显示目标进度
    // 出差固定8小时无需显示目标进度
    if (type == AppConstants.typeOvertime ||
        type == AppConstants.typeRestDay ||
        type == '休息' ||
        type == AppConstants.typeLeave ||
        type == AppConstants.typeBusinessTrip) {
      return const SizedBox.shrink();
    }

    // 判断是否是今天
    final isToday = _isToday();

    // 如果不是今天,显示历史统计信息
    if (!isToday) {
      return _buildHistoricalStats(hours, type);
    }

    // 今天显示目标进度
    // 根据开关状态选择使用的工时
    double displayHours = hours;
    if (!_useCheckInTime) {
      // 使用当前手机时间计算
      final checkIn = _attendanceData?['checkInTime'] as String?;
      if (checkIn != null) {
        displayHours = _calculateCurrentHoursFromNow(checkIn);
      }
    }

    final targetProgress = TargetProgressHelper.buildDailyProgress(
      displayHours: displayHours,
      baseTarget: _baseTarget,
      smartSort: _smartSort,
      pinnedTarget: _pinnedTarget,
    );
    final sortedTargetData = targetProgress.sortedTargetData;
    final highestAchievedTarget = targetProgress.highestAchievedTarget;
    final nextToAchieveTarget = targetProgress.nextToAchieveTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.flag_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              '目标进度',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '(长按置顶)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const Spacer(),
            // 时间计算方式开关
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _useCheckInTime ? '打卡时间' : '当前时间',
                  style: TextStyle(
                    fontSize: 12,
                    color: _useCheckInTime
                        ? AppColors.primaryDark
                        : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _useCheckInTime,
                    onChanged: (value) async {
                      await HapticUtils.selectionClick();
                      setState(() {
                        _useCheckInTime = value;
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedTargetData.map((data) {
          final target = data['target'] as int;
          final targetHours = data['targetHours'] as double;
          final isCompleted = data['isCompleted'] as bool;

          // 判断是否是特殊标记的目标
          final isHighestAchieved = target == highestAchievedTarget;
          final isNextToAchieve = target == nextToAchieveTarget;

          // 基础目标（可配置，默认120%）
          final isBaseTarget = target == _baseTarget;

          // 已完成的折叠显示(除了最高达成)
          if (isCompleted && !isHighestAchieved) {
            return _buildCollapsedGoal(
              target,
              displayHours,
              targetHours,
              isBaseTarget: isBaseTarget,
            );
          }

          // 未完成的展开显示
          return _buildExpandedGoal(
            target,
            displayHours,
            targetHours,
            isCompleted,
            isBaseTarget,
            isHighestAchieved: isHighestAchieved,
            isNextToAchieve: isNextToAchieve,
          );
        }),
      ],
    );
  }

  /// 折叠的目标显示
  Widget _buildCollapsedGoal(
    int target,
    double currentHours,
    double targetHours, {
    bool isBaseTarget = false,
  }) {
    final isPinned = _pinnedTarget == target;
    return GestureDetector(
      onLongPress: () async {
        await HapticFeedback.mediumImpact();
        _togglePinnedTarget(target);
      },
      child: Card(
        color: AppColors.successLight,
        margin: const EdgeInsets.only(bottom: 8),
        shape: isPinned
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: AppColors.warning, width: 2),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$target% 目标已达成',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isBaseTarget) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '基准',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (isPinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin, size: 14, color: AppColors.warning),
              ],
              const Spacer(),
              PrecisionText(
                '${WorkTimeCalculator.formatHours(currentHours)}h / ${WorkTimeCalculator.formatHours(targetHours)}h',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开的目标显示
  Widget _buildExpandedGoal(
    int target,
    double currentHours,
    double targetHours,
    bool isCompleted,
    bool isBaseTarget, {
    bool isHighestAchieved = false,
    bool isNextToAchieve = false,
  }) {
    final progressPercentageRaw = WorkTimeCalculator.calculatePercentage(
      hours: currentHours,
      baseHours: targetHours,
      min: 0,
      max: 100,
    );
    final progress = progressPercentageRaw / 100;

    Color getProgressColor() {
      if (isCompleted) return AppColors.success;
      if (isBaseTarget) return AppColors.warning;
      return AppColors.primary;
    }

    // 特殊标记的边框颜色
    Color? getBorderColor() {
      if (isHighestAchieved) return AppColors.success;
      if (isNextToAchieve) return AppColors.primaryDark;
      return null;
    }

    // 特殊标记的标签
    Widget? getSpecialBadge() {
      if (isHighestAchieved) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '最高达成',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      if (isNextToAchieve) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '即将达成',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      return null;
    }

    final isPinned = _pinnedTarget == target;

    // 边框颜色优先级：置顶 > 最高达成 > 即将达成
    Color? actualBorderColor() {
      if (isPinned) return AppColors.warning;
      return getBorderColor();
    }

    return GestureDetector(
      onLongPress: () async {
        await HapticFeedback.mediumImpact();
        _togglePinnedTarget(target);
      },
      child: Card(
        color: isBaseTarget && !isCompleted
            ? AppColors.warningLight
            : Colors.white,
        shape: actualBorderColor() != null
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: actualBorderColor()!, width: 2),
              )
            : null,
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: getProgressColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$target% 目标',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: getProgressColor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.push_pin, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            '置顶',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isPinned && getSpecialBadge() != null)
                    getSpecialBadge()!,
                  if (!isPinned && isBaseTarget && getSpecialBadge() == null)
                    Container(
                      margin: const EdgeInsets.only(left: 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '完成率基准',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  const Spacer(),
                  PrecisionText(
                    '${WorkTimeCalculator.formatHours(currentHours)} / ${WorkTimeCalculator.formatHours(targetHours)}h',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 本日完成进度条
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '本日进度',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PrecisionText(
                        '${WorkTimeCalculator.formatHours(progressPercentageRaw)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: getProgressColor(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getProgressColor(),
                    ),
                    minHeight: 6,
                  ),
                ],
              ),

              // 还需时间和预计完成时间(仅当今天且未完成时显示)
              if (!isCompleted && _isToday()) ...[
                const SizedBox(height: 12),
                _buildTimeEstimation(
                  targetHours,
                  currentHours,
                  getProgressColor(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 判断是否是今天（工作日）
  bool _isToday() {
    return DateHelper.isWorkToday(_selectedDate);
  }

  /// 构建时间预估信息(基于上班打卡时间计算)
  Widget _buildTimeEstimation(
    double targetHours,
    double currentHours,
    Color color,
  ) {
    final remaining = targetHours - currentHours;
    if (remaining <= 0) return const SizedBox.shrink();

    // 获取上班打卡时间
    final checkInTime = _attendanceData?['checkInTime'] as String?;
    if (checkInTime == null || checkInTime.isEmpty) {
      return const SizedBox.shrink();
    }

    final checkInMinutes = WorkTimeCalculator.parseTimeToMinutes(checkInTime);
    if (checkInMinutes == null) return const SizedBox.shrink();

    try {
      // 解析上班时间
      final parts = checkInTime.split(':');
      final checkInHour = int.parse(parts[0]);
      final checkInMinute = int.parse(parts[1]);

      // 计算预计完成时间
      final today = DateTime.now();
      var predictedEnd = DateTime(
        today.year,
        today.month,
        today.day,
        checkInHour,
        checkInMinute,
      );

      // 加上目标工时(分钟)
      predictedEnd = predictedEnd.add(
        Duration(minutes: (targetHours * 60).toInt()),
      );

      // 判断是否跨越午休时间,如果跨越需要加上午休时长
      final predictedEndMinutes = predictedEnd.hour * 60 + predictedEnd.minute;
      final lunchDeductionMinutes = WorkTimeCalculator.getLunchDeductionMinutes(
        checkInMinutes,
        predictedEndMinutes,
      );
      if (lunchDeductionMinutes > 0) {
        predictedEnd = predictedEnd.add(
          Duration(minutes: lunchDeductionMinutes),
        );
      }

      final formatter = DateFormat('HH:mm');

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '预计完成: ${formatter.format(predictedEnd)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // 计算预计完成时间失败
      return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () async {
              await HapticUtils.lightImpact();
              _showEditDialog();
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('修改类型'),
          ),
        ),
      ],
    );
  }
}

class _EditDayDialog extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? attendanceData;
  final bool canModify;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Future<void> Function()? onRestore; // 恢复默认回调

  const _EditDayDialog({
    required this.date,
    required this.initialData,
    required this.attendanceData,
    required this.canModify,
    required this.onSave,
    this.onRestore,
  });

  @override
  State<_EditDayDialog> createState() => _EditDayDialogState();
}

class _EditDayDialogState extends State<_EditDayDialog> {
  late String currentType;
  late bool isOvertime;
  late bool isCustomHours;
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentType = widget.initialData?['type'] ?? AppConstants.typeWorkday;
    isOvertime = widget.initialData?['isOvertime'] ?? false;
    isCustomHours = widget.initialData?['isCustomHours'] ?? false;

    // 初始化自定义时间输入
    String? initialCheckIn;
    String? initialCheckOut;

    if (widget.initialData != null) {
      initialCheckIn = widget.initialData!['customCheckIn'] as String?;
      initialCheckOut = widget.initialData!['customCheckOut'] as String?;
    }

    if (initialCheckIn != null) _checkInController.text = initialCheckIn;
    if (initialCheckOut != null) _checkOutController.text = initialCheckOut;

    if (widget.attendanceData != null) {
      final attCheckIn = _formatTime(widget.attendanceData!['checkInTime']);
      final attCheckOut = _formatTime(widget.attendanceData!['checkOutTime']);

      if (_checkInController.text.isEmpty && attCheckIn.isNotEmpty) {
        _checkInController.text = attCheckIn;
      }
      if (_checkOutController.text.isEmpty && attCheckOut.isNotEmpty) {
        _checkOutController.text = attCheckOut;
      }
    }

    // 如果没有数据，设置默认值(与月度页面保持一致)
    if (_checkInController.text.isEmpty) _checkInController.text = '09:00';
    if (_checkOutController.text.isEmpty) _checkOutController.text = '18:00';
  }

  String _formatTime(dynamic time) {
    if (time == null || time.toString().isEmpty) return '';
    final timeStr = time.toString().trim();
    // 处理 "-" 或无效时间
    if (timeStr == '-' || timeStr == '--' || timeStr == '--:--') return '';
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        // 验证是否是有效数字
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }
    }
    // 尝试智能解析纯数字
    return _parseTimeInput(timeStr);
  }

  /// 智能解析时间输入 (支持 0850, 850, 08:50, 08-50, 08.50 等)
  String _parseTimeInput(String input) {
    // 移除所有非数字字符
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) return '';

    // 补齐到4位
    String padded = digits.padLeft(4, '0');
    if (padded.length > 4) {
      padded = padded.substring(padded.length - 4);
    }

    // 格式化为 HH:MM
    String hourStr = padded.substring(0, 2);
    String minuteStr = padded.substring(2, 4);

    // 严格限制：小时 00-23，分钟 00-59
    int hour = int.parse(hourStr);
    int minute = int.parse(minuteStr);

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ''; // Invalid time, return empty string
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  double _calculateHours() {
    if (currentType == AppConstants.typeBusinessTrip && !isCustomHours) {
      return 8.0;
    }
    if (currentType == AppConstants.typeLeave) return 0.0;

    // 先智能解析输入
    final checkIn = _parseTimeInput(_checkInController.text);
    final checkOut = _parseTimeInput(_checkOutController.text);

    if (checkIn.isEmpty || checkOut.isEmpty) return 0.0;

    // 使用统一的工时计算工具类
    return WorkTimeCalculator.calculateWorkHoursStr(checkIn, checkOut);
  }

  @override
  Widget build(BuildContext context) {
    final hasAttendance = widget.attendanceData?['checkInTime'] != null;

    return AlertDialog(
      title: Text('编辑 ${DateFormat('MM月dd日', 'zh_CN').format(widget.date)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('工作类型:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.allWorkTypes.map((type) {
                final isDisabled =
                    !widget.canModify &&
                    (type == AppConstants.typeLeave ||
                        type == AppConstants.typeOvertime ||
                        type == AppConstants.typeWorkday) &&
                    !hasAttendance;
                final isSelected = currentType == type;

                Color typeColor;
                switch (type) {
                  case '工作日':
                    typeColor = AppColors.success;
                    break;
                  case '加班日':
                    typeColor = AppColors.overtime;
                    break;
                  case '出差':
                    typeColor = AppColors.warning;
                    break;
                  case '请假':
                    typeColor = AppColors.error;
                    break;
                  case '自定义':
                    typeColor = AppColors.custom;
                    break;
                  default:
                    typeColor = Colors.grey;
                }

                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  backgroundColor: typeColor.withValues(alpha: 0.2),
                  selectedColor: typeColor,
                  disabledColor: Colors.grey.withValues(alpha: 0.1),
                  onSelected: isDisabled
                      ? null
                      : (selected) async {
                          if (selected) {
                            await HapticUtils.selectionClick();
                            setState(() {
                              currentType = type;
                            });
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (currentType == AppConstants.typeBusinessTrip ||
                currentType == AppConstants.typeCustom) ...[
              const Text(
                '工时类型:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('☀️ 正常'),
                    selected: !isOvertime,
                    onSelected: (selected) async {
                      await HapticUtils.selectionClick();
                      setState(() => isOvertime = !selected);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('🌙 加班'),
                    selected: isOvertime,
                    onSelected: (selected) async {
                      await HapticUtils.selectionClick();
                      setState(() => isOvertime = selected);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 出差类型的 工时模式选择 (默认8h / 自定义)
            if (currentType == AppConstants.typeBusinessTrip) ...[
              const Text(
                '工时设置:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('默认 8h'),
                    selected: !isCustomHours,
                    onSelected: (selected) async {
                      await HapticUtils.selectionClick();
                      setState(() {
                        isCustomHours = !selected;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('自定义'),
                    selected: isCustomHours,
                    onSelected: (selected) async {
                      await HapticUtils.selectionClick();
                      setState(() {
                        isCustomHours = selected;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (currentType == AppConstants.typeCustom ||
                (currentType == AppConstants.typeBusinessTrip &&
                    isCustomHours)) ...[
              const Text(
                '自定义时间:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '上班',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _checkInController,
                          decoration: const InputDecoration(
                            hintText: '09:00',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          keyboardType: TextInputType.datetime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '下班',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _checkOutController,
                          decoration: const InputDecoration(
                            hintText: '18:00',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          keyboardType: TextInputType.datetime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 恢复默认按钮(仅在有手动修改时显示)
        if (widget.onRestore != null)
          TextButton.icon(
            icon: const Icon(Icons.restore, color: AppColors.error),
            label: const Text('恢复默认', style: TextStyle(color: AppColors.error)),
            onPressed: () async {
              await HapticUtils.mediumImpact();
              await widget.onRestore!();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        TextButton(
          onPressed: () async {
            await HapticUtils.lightImpact();
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await HapticUtils.mediumImpact();
            final hours = _calculateHours();
            await widget.onSave({
              'type': currentType,
              'hours': hours,
              'isOvertime': isOvertime,
              'isManual': true,
              'isCustomHours': isCustomHours,
              if (currentType == AppConstants.typeCustom ||
                  (currentType == AppConstants.typeBusinessTrip &&
                      isCustomHours)) ...{
                'customCheckIn': _parseTimeInput(_checkInController.text),
                'customCheckOut': _parseTimeInput(_checkOutController.text),
              },
            });
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    super.dispose();
  }
}

/// 恭喜完成对话框
class _CongratulationsDialog extends StatefulWidget {
  final VoidCallback onContinue;

  const _CongratulationsDialog({required this.onContinue});

  @override
  State<_CongratulationsDialog> createState() => _CongratulationsDialogState();
}

class _CongratulationsDialogState extends State<_CongratulationsDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _rotateAnimation = Tween<double>(
      begin: -0.1,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 庆祝图标
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.warningLight, AppColors.warning],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 恭喜文字
                    const Text(
                      '🎉 恭喜！',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      '你已经掌握了下拉刷新的操作',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '接下来了解更多实用功能吧',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),

                    // 继续按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '查看功能说明',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 跳过按钮
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '稍后再看',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
