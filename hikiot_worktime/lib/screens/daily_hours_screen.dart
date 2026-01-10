import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hikiot_api_client.dart';
import '../services/storage_service.dart';
import '../services/token_expired_service.dart';
import '../utils/work_time_calculator.dart';
import '../utils/attendance_parser.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_helper.dart';
import '../widgets/home_button.dart';
import '../widgets/haptic_refresh_indicator.dart';
import '../widgets/pull_refresh_guide.dart';
import 'feature_guide_page.dart';
import 'photo_preview_screen.dart';

class DailyHoursScreen extends StatefulWidget {
  const DailyHoursScreen({super.key});

  @override
  DailyHoursScreenState createState() => DailyHoursScreenState();
}

class DailyHoursScreenState extends State<DailyHoursScreen>
    with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  DateTime _selectedDate = DateHelper.getWorkDate();
  Map<String, dynamic>? _dayData;
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = false;
  String? _teamNo;
  String? _personNo;
  Map<String, String> _holidayPlan = {}; // 节假日计划
  bool _useCheckInTime = true; // 默认使用打卡时间计算
  int? _pinnedTarget; // 置顶的目标
  bool _smartSort = true; // 智能排序开关
  int _baseTarget = 120; // 基础目标百分比
  bool _showOnboarding = false; // 是否显示新手引导
  bool _isUserPullRefresh = false; // 是否是用户主动下拉刷新

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('zh_CN', null);
    _loadPinnedTarget();
    _loadSmartSort();
    _loadDailyData();
    _autoUpdateTodayHours(); // 自动更新今日工时
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
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

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
    final newTarget = _pinnedTarget == target ? null : target;
    await _storage.savePinnedTarget(newTarget);
    setState(() {
      _pinnedTarget = newTarget;
    });
  }

  /// 自动更新今日工时(仅当查看今天且没有手动修改时)
  Future<void> _autoUpdateTodayHours() async {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    if (!isToday) return;

    // 检查是否有手动修改
    final prefs = await SharedPreferences.getInstance();
    final teamNo = prefs.getString('personNo');
    if (teamNo != null) {
      final marks = await _storage.loadCalendarMarks(teamNo);
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final isManual = marks[dateKey]?['isManual'] ?? false;

      if (!isManual) {
        // 没有手动修改,自动刷新
        await _fetchAttendanceData();
      }
    }
  }

  /// 生成目标列表，确保包含基础目标
  List<int> _generateTargetList(int baseTarget) {
    final targets = <int>{100, 110, 120, 130, 140, 150, 160};
    targets.add(baseTarget); // 确保基础目标在列表中
    final sortedList = targets.toList()..sort();
    return sortedList;
  }

  /// 公开方法:从其他页面切换回来时刷新数据
  Future<void> refreshData() async {
    await _loadSmartSort();
    // 重新加载所有数据（包括手动标记），确保与月度页面的修改同步
    await _loadDailyData();
  }

  /// 加载每日数据
  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);

    try {
      // 先加载设置（确保智能排序等设置是最新的）
      _smartSort = await _storage.loadSmartSort();
      _pinnedTarget = await _storage.loadPinnedTarget();
      _baseTarget = await _storage.loadBaseTarget();

      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 获取teamNo和personNo
      _teamNo = prefs.getString('teamNo');
      _personNo = prefs.getString('personNo');

      if (_teamNo == null) {
        print('未找到teamNo,无法加载数据');
        setState(() => _isLoading = false);
        return;
      }

      // 1. 加载节假日计划(和月度统计一样的逻辑)
      _holidayPlan = await _storage.getHolidayPlan(_selectedDate.year);
      if (_holidayPlan.isEmpty) {
        // 使用默认规则
        _holidayPlan = _storage.generateDefaultPlan(
          _selectedDate.year,
          _selectedDate.month,
        );
      }

      // 2. 确定默认类型(从节假日计划)
      final defaultType =
          _holidayPlan[dateKey] ??
          (_selectedDate.weekday <= 5 ? '工作日' : '非工作日');

      // 3. 初始化dayData为默认值
      _dayData = {'type': defaultType, 'isManual': false, 'hours': 0.0};

      // 4. 加载用户手动标记(和月度统计一样)
      final savedMarks = await _storage.loadCalendarMarks(_teamNo!);
      final savedMark = savedMarks[dateKey];

      if (savedMark != null) {
        // 应用手动标记(覆盖默认类型)
        _dayData!['type'] = savedMark['type'] ?? defaultType;
        _dayData!['isManual'] = true;

        if (savedMark['isOvertime'] != null) {
          _dayData!['isOvertime'] = savedMark['isOvertime'];
        }

        if (savedMark['type'] == '自定义') {
          _dayData!['customCheckIn'] = savedMark['customCheckIn'];
          _dayData!['customCheckOut'] = savedMark['customCheckOut'];
          // 根据自定义时间计算工时
          final checkIn = savedMark['customCheckIn'] as String?;
          final checkOut = savedMark['customCheckOut'] as String?;
          if (checkIn != null && checkOut != null) {
            _dayData!['hours'] = WorkTimeCalculator.calculateWorkHoursStr(
              checkIn,
              checkOut,
            );
          }
        } else if (savedMark['type'] == '出差') {
          // 出差固定8小时
          _dayData!['hours'] = 8.0;
        } else if (savedMark['type'] == '请假') {
          // 请假0小时
          _dayData!['hours'] = 0.0;
        }

        // 保存其他字段
        if (savedMark['targets'] != null) {
          _dayData!['targets'] = savedMark['targets'];
        }
      }

      // 5. 如果是今天或过去日期,从API获取考勤数据
      final workDate = DateHelper.getWorkDate();
      if (!_selectedDate.isAfter(workDate)) {
        await _fetchAttendanceData();
      }

      // 如果正在显示引导且是用户主动下拉刷新，完成引导
      if (_showOnboarding && _isUserPullRefresh) {
        _isUserPullRefresh = false;
        _completeOnboarding();
      }
    } catch (e) {
      print('加载每日数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 从API获取考勤数据
  Future<void> _fetchAttendanceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('hikiot_token');
      final personNo = prefs.getString('personNo');

      if (token == null || personNo == null) {
        // Token或personNo为空，可能需要重新登录
        if (mounted && token == null) {
          await TokenExpiredService.handleTokenExpired(context);
        }
        return;
      }

      final apiClient = HikiotApiClient(token: token);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await apiClient.getDailyAttendance(dateStr, personNo);

      // 检查是否是Token失效导致的null响应
      if (data == null) {
        // 尝试获取账户信息来确认是否是Token问题
        final accountDetail = await apiClient.getAccountDetail();
        if (accountDetail == null && mounted) {
          // 无法获取账户信息，Token已失效
          await TokenExpiredService.handleTokenExpired(context);
          return;
        }
      }

      if (mounted && data != null) {
        // 使用统一的解析器
        final attendance = AttendanceParser.parseFromResponse(data);

        setState(() {
          _attendanceData = {
            'checkInTime': attendance.checkIn,
            'checkOutTime': attendance.checkOut,
            'checkInPhotoUrl': attendance.checkInPhotoUrl,
            'checkOutPhotoUrl': attendance.checkOutPhotoUrl,
          };
        });
      }
    } catch (e) {
      print('获取每日考勤数据失败: $e');
      // 检查是否是Token失效导致的错误
      if (mounted && TokenExpiredService.isTokenExpiredError(e)) {
        await TokenExpiredService.handleTokenExpired(context);
      }
    }
  }

  /// 计算工时
  double _calculateHours() {
    final type = _dayData?['type'] ?? '工作日';

    // 出差恒定8小时
    if (type == '出差') {
      return 8.0;
    }

    // 如果是自定义类型,从dayData获取工时
    if (type == '自定义' && _dayData != null) {
      final hours = _dayData!['hours'];
      if (hours is double) return hours;
      if (hours is int) return hours.toDouble();
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    final type = _dayData?['type'] ?? '工作日';

    // 没有打卡的休息日不能改为请假/加班/工作
    final hasAttendance = _attendanceData?['checkInTime'] != null;
    final isRest = type == '非工作日' || type == '休息';
    final isManual = _dayData?['isManual'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => _EditDayDialog(
        date: _selectedDate,
        initialData: _dayData,
        attendanceData: _attendanceData,
        canModify: !(isRest && !hasAttendance),
        onSave: (newData) async {
          // 确保有teamNo
          if (_teamNo == null) {
            final prefs = await SharedPreferences.getInstance();
            _teamNo = prefs.getString('personNo');
          }

          if (_teamNo != null) {
            final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

            // 使用StorageService保存
            final marks = await _storage.loadCalendarMarks(_teamNo!);
            marks[dateKey] = newData;
            await _storage.saveCalendarMarks(_teamNo!, marks);

            setState(() {
              _dayData = newData;
            });

            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('保存成功')));
            }
          }
        },
        onRestore: isManual
            ? () async {
                // 恢复默认类型
                if (_teamNo == null) {
                  final prefs = await SharedPreferences.getInstance();
                  _teamNo = prefs.getString('personNo');
                }

                if (_teamNo != null) {
                  final dateKey = DateFormat(
                    'yyyy-MM-dd',
                  ).format(_selectedDate);

                  // 从节假日计划获取默认类型
                  final defaultType =
                      _holidayPlan[dateKey] ??
                      (_selectedDate.weekday <= 5 ? '工作日' : '非工作日');

                  // 删除手动标记
                  final marks = await _storage.loadCalendarMarks(_teamNo!);
                  marks.remove(dateKey);
                  await _storage.saveCalendarMarks(_teamNo!, marks);

                  // 恢复默认时清除所有手动设置的字段（type, hours, isManual, isOvertime）
                  // 只保留从 API 获取的考勤数据
                  setState(() {
                    _dayData = {
                      'type': defaultType,
                      'isManual': false,
                      // 从考勤数据恢复工时（如果有的话）
                      if (_attendanceData != null) ...{
                        'hours': _attendanceData!['hours'],
                        'checkIn': _attendanceData!['checkInTime'],
                        'checkOut': _attendanceData!['checkOutTime'],
                      },
                    };
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已恢复为默认类型: $defaultType')),
                    );
                  }
                }
                Navigator.pop(context);
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
                const Text('上班打卡', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _buildPhotoWidget(checkInPhotoUrl, 'checkIn'),
                const SizedBox(height: 16),
              ],
              if (checkOutPhotoUrl != null) ...[
                const Text('下班打卡', style: TextStyle(fontWeight: FontWeight.w500)),
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
            builder: (context) => PhotoPreviewScreen(
              photoUrl: photoUrl,
              heroTag: heroTag,
            ),
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
    final type = _dayData?['type'] ?? '工作日';

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
                        _buildTypeWarning(type),
                        const SizedBox(height: 12),
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

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: Colors.blue[700]),
        title: Text(
          DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDate),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        trailing: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
        onTap: () async {
          await HapticUtils.selectionClick();
          _selectDate();
        },
      ),
    );
  }

  /// 类型提示警告（放在顶部）
  Widget _buildTypeWarning(String type) {
    final isManual = _dayData?['isManual'] ?? false;

    // 获取类型颜色
    Color typeColor;
    IconData typeIcon;
    String? warningText;

    switch (type) {
      case '工作日':
        typeColor = Colors.green;
        typeIcon = Icons.work;
        break;
      case '加班日':
        typeColor = Colors.purple;
        typeIcon = Icons.more_time;
        break;
      case '出差':
        typeColor = Colors.amber;
        typeIcon = Icons.flight_takeoff;
        warningText = '出差固定计 8 小时工时';
        break;
      case '请假':
        typeColor = Colors.red;
        typeIcon = Icons.event_busy;
        warningText = '请假统计工时为 0，如需统计请改为 工作日 或 自定义 类型';
        break;
      case '自定义':
        typeColor = Colors.blue;
        typeIcon = Icons.tune;
        break;
      case '非工作日':
        typeColor = Colors.grey;
        typeIcon = Icons.weekend;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help_outline;
    }

    // 检查是否有照片
    final hasPhoto = _attendanceData?['checkInPhotoUrl'] != null ||
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  color: isManual ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isManual ? '手动' : '自动',
                  style: TextStyle(
                    fontSize: 10,
                    color: isManual ? Colors.orange[700] : Colors.green[700],
                  ),
                ),
              ),
              const Spacer(),
              // 查看照片按钮
              if (hasPhoto)
                GestureDetector(
                  onTap: () => _showPhotoDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          '打卡照片',
                          style: TextStyle(fontSize: 11, color: Colors.blue[700]),
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

  Widget _buildHoursCard(double hours, String type) {
    // 截断到2位小数(不四舍五入)
    final hoursTruncated = (hours * 100).truncate() / 100;

    return Column(
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '今日打卡工时',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      hoursTruncated.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '小时',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
                // 只有非加班、非休息日才显示工时百分比
                if (type != '加班日' && type != '非工作日' && type != '休息') ...[
                  const SizedBox(height: 8),
                  Text(
                    '已完成 ${((hours / 8.0 * 100 * 100).truncate() / 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckInOutCard(),
        // 自定义类型显示设置的时间
        if (type == '自定义') ...[
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.edit_calendar, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自定义工时时间',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dayData?['customCheckIn'] ?? '09:00'} - ${_dayData?['customCheckOut'] ?? '18:00'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.login, color: Colors.green[600], size: 20),
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
                          color: Colors.green[700],
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
                            ? Colors.orange[600]
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
                              ? Colors.orange[700]
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
    final actualHoursTruncated = (actualHours * 100).truncate() / 100;
    final estimatedHoursTruncated = (estimatedHours * 100).truncate() / 100;

    final actualPercentageRaw = (actualHours / 8.0 * 100).toDouble().clamp(
      0.0,
      200.0,
    );
    final actualPercentage = (actualPercentageRaw * 100).truncate() / 100;

    final estimatedPercentageRaw = (estimatedHours / 8.0 * 100)
        .toDouble()
        .clamp(0.0, 200.0);
    final estimatedPercentage = (estimatedPercentageRaw * 100).truncate() / 100;

    Color getPercentageColor(double percentage) {
      if (percentage >= _baseTarget) return Colors.green;
      if (percentage >= 100) return Colors.orange;
      return Colors.blue;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 信息1: 实际打卡工时
            Row(
              children: [
                Icon(Icons.fact_check, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '按照打卡时间',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Text(
                  '工时: ${actualHoursTruncated.toStringAsFixed(2)}h',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(actualPercentage),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${actualPercentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(actualPercentage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 信息2: 现在下班的预估工时
            Row(
              children: [
                Icon(Icons.trending_up, size: 20, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  '如果现在下班',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Text(
                  '工时: ${estimatedHoursTruncated.toStringAsFixed(2)}h',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(estimatedPercentage),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${estimatedPercentage.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getPercentageColor(estimatedPercentage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建历史统计信息(用于过去的日期)
  Widget _buildHistoricalStats(double hours, String type) {
    final checkIn = _attendanceData?['checkInTime'] as String?;
    final checkOut = _attendanceData?['checkOutTime'] as String?;

    // 计算工时完成率 - 截断到2位小数
    final completionRaw = (hours / 8.0 * 100).clamp(0, 200);
    final completion = (completionRaw * 100).truncate() / 100;

    // 截断工时到2位小数
    final hoursTruncated = (hours * 100).truncate() / 100;

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
        final totalHoursTruncated = (totalHours * 100).truncate() / 100;
        workDuration = '${totalHoursTruncated.toStringAsFixed(2)}小时';
      } catch (e) {
        workDuration = '--';
      }
    }

    Color getCompletionColor() {
      if (completion >= 100) return Colors.green;
      if (completion >= 80) return Colors.orange;
      return Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assessment, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              '当日统计',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
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
                    Text(
                      '${completion.toStringAsFixed(2)}%',
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
                  value: (completion / 100).clamp(0.0, 1.0),
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
                        '${hoursTruncated.toStringAsFixed(2)}h',
                        Icons.access_time,
                        Colors.blue,
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.grey[300]),
                    Expanded(
                      child: _buildStatItem(
                        '上班时长',
                        workDuration,
                        Icons.timer,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                if (type == '出差') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight_takeoff,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '出差类型(固定8小时)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (type == '自定义') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '自定义: ${_dayData?['customCheckIn'] ?? '09:00'} - ${_dayData?['customCheckOut'] ?? '18:00'}',
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
        Text(
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
    final type = _dayData?['type'] ?? '工作日';

    // 加班日、非工作日、请假、出差 不显示目标进度
    // 出差固定8小时无需显示目标进度
    if (type == '加班日' ||
        type == '非工作日' ||
        type == '休息' ||
        type == '请假' ||
        type == '出差') {
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

    // 动态生成目标列表，确保包含基础目标
    final baseTargets = _generateTargetList(_baseTarget);
    final extendedTargets = [170, 180, 190, 200, 220, 240, 260, 280, 300];

    final currentPercentage = (displayHours / 8.0 * 100);
    final allTargets = currentPercentage >= 160
        ? [...baseTargets, ...extendedTargets]
        : baseTargets;

    // 找出最高达成和即将达成的目标
    int? highestAchievedTarget;
    int? nextToAchieveTarget;

    for (final target in allTargets) {
      final targetHours = 8.0 * target / 100;
      if (displayHours >= targetHours) {
        highestAchievedTarget = target;
      } else if (nextToAchieveTarget == null) {
        nextToAchieveTarget = target;
      }
    }

    // 构建目标数据
    final List<Map<String, dynamic>> targetData = [];
    for (final target in allTargets) {
      final targetHours = 8.0 * target / 100;
      final isCompleted = displayHours >= targetHours;

      targetData.add({
        'target': target,
        'targetHours': targetHours,
        'isCompleted': isCompleted,
      });
    }

    // 排序逻辑
    List<Map<String, dynamic>> sortedTargetData;

    if (_smartSort) {
      // 智能排序: 最高达成 → 即将达成 → 其他(升序) → 全完成
      final completed = targetData
          .where((d) => d['isCompleted'] as bool)
          .toList();
      final incomplete = targetData
          .where((d) => !(d['isCompleted'] as bool))
          .toList();

      final highestAchieved = completed.isNotEmpty
          ? [completed.last]
          : <Map<String, dynamic>>[];
      final nextToAchieve = incomplete.isNotEmpty
          ? [incomplete.first]
          : <Map<String, dynamic>>[];
      final others = incomplete.skip(1).toList();
      final bothCompleted = completed.length > 1
          ? completed.sublist(0, completed.length - 1)
          : <Map<String, dynamic>>[];

      sortedTargetData = [
        ...highestAchieved,
        ...nextToAchieve,
        ...others,
        ...bothCompleted,
      ];
    } else {
      // 普通排序: 全部按目标从低到高
      sortedTargetData = List.from(targetData);
      sortedTargetData.sort(
        (a, b) => (a['target'] as int).compareTo(b['target'] as int),
      );
    }

    // 如果有置顶目标，将其移到最前面
    if (_pinnedTarget != null) {
      final pinnedIndex = sortedTargetData.indexWhere(
        (d) => d['target'] == _pinnedTarget,
      );
      if (pinnedIndex > 0) {
        final pinnedData = sortedTargetData.removeAt(pinnedIndex);
        sortedTargetData.insert(0, pinnedData);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag, color: Colors.blue[700], size: 20),
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
                        ? Colors.blue[700]
                        : Colors.orange[700],
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
        }).toList(),
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
        color: Colors.green[50],
        margin: const EdgeInsets.only(bottom: 8),
        shape: isPinned
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.amber, width: 2),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
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
                    color: Colors.orange,
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
                Icon(Icons.push_pin, size: 14, color: Colors.amber[700]),
              ],
              const Spacer(),
              Text(
                '${currentHours.toStringAsFixed(1)}h / ${targetHours.toStringAsFixed(1)}h',
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
    final progress = currentHours / targetHours;
    final progressPercentageRaw = (progress * 100).clamp(0, 100);
    // 截断到2位小数
    final progressPercentage = (progressPercentageRaw * 100).truncate() / 100;

    Color getProgressColor() {
      if (isCompleted) return Colors.green;
      if (isBaseTarget) return Colors.orange;
      return Colors.blue;
    }

    // 特殊标记的边框颜色
    Color? getBorderColor() {
      if (isHighestAchieved) return Colors.green;
      if (isNextToAchieve) return Colors.blue[700];
      return null;
    }

    // 特殊标记的标签
    Widget? getSpecialBadge() {
      if (isHighestAchieved) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green,
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
            color: Colors.blue[700],
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
      if (isPinned) return Colors.amber;
      return getBorderColor();
    }

    return GestureDetector(
      onLongPress: () async {
        await HapticFeedback.mediumImpact();
        _togglePinnedTarget(target);
      },
      child: Card(
        color: isBaseTarget && !isCompleted ? Colors.orange[50] : Colors.white,
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
                        color: Colors.amber,
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '完成率基准',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${(currentHours * 100).truncate() / 100} / ${(targetHours * 100).truncate() / 100}h',
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
                      Text(
                        '${progressPercentage.toStringAsFixed(2)}%',
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
      if (WorkTimeCalculator.shouldDeductLunch(
        checkInMinutes,
        predictedEndMinutes,
      )) {
        predictedEnd = predictedEnd.add(
          Duration(minutes: WorkTimeCalculator.defaultLunchDurationMinutes),
        );
      }

      final formatter = DateFormat('HH:mm');

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
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
      print('计算预计完成时间失败: $e');
      return const SizedBox.shrink();
    }
  }

  /// 操作按钮行 - 使用 iPhone 8 Home 键风格的触感
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: HomeButtonIcon(
            onPressed: _showEditDialog,
            icon: Icons.edit,
            label: '修改类型',
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: HomeButtonIcon(
            onPressed: _updateHolidays,
            icon: Icons.event,
            label: '更新节假日',
            isOutlined: true,
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// 更新节假日
  Future<void> _updateHolidays() async {
    // 验证年份范围:2010年到下个月末
    final now = DateTime.now();
    final nextMonthEnd = DateTime(now.year, now.month + 2, 0); // 下个月最后一天
    final targetMonthEnd = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ); // 选择月份最后一天

    if (_selectedDate.year < 2010) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法更新2010年之前的节假日'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (targetMonthEnd.isAfter(nextMonthEnd)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法更新${now.year}年${now.month + 1}月之后的节假日'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _storage.updateHolidaysFromAPI(_selectedDate.year);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '节假日更新成功' : '节假日更新失败，使用默认规则'),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }

      // 重新加载数据
      await _loadDailyData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('节假日更新失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _EditDayDialog extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? attendanceData;
  final bool canModify;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback? onRestore; // 恢复默认回调

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
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentType = widget.initialData?['type'] ?? '工作日';
    isOvertime = widget.initialData?['isOvertime'] ?? false;

    if (widget.attendanceData != null) {
      _checkInController.text = _formatTime(
        widget.attendanceData!['checkInTime'],
      );
      _checkOutController.text = _formatTime(
        widget.attendanceData!['checkOutTime'],
      );
    }
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
    final hour = padded.substring(0, 2);
    final minute = padded.substring(2, 4);

    return '$hour:$minute';
  }

  double _calculateHours() {
    if (currentType == '出差') return 8.0;
    if (currentType == '请假') return 0.0;

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
              children: ['工作日', '加班日', '出差', '请假', '自定义', '非工作日'].map((type) {
                final isDisabled =
                    !widget.canModify &&
                    (type == '请假' || type == '加班日' || type == '工作日') &&
                    !hasAttendance;
                final isSelected = currentType == type;

                Color typeColor;
                switch (type) {
                  case '工作日':
                    typeColor = Colors.green;
                    break;
                  case '加班日':
                    typeColor = Colors.purple;
                    break;
                  case '出差':
                    typeColor = Colors.amber;
                    break;
                  case '请假':
                    typeColor = Colors.red;
                    break;
                  case '自定义':
                    typeColor = Colors.blue;
                    break;
                  default:
                    typeColor = Colors.grey;
                }

                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  backgroundColor: typeColor.withOpacity(0.2),
                  selectedColor: typeColor,
                  disabledColor: Colors.grey.withOpacity(0.1),
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

            if (currentType == '出差' || currentType == '自定义') ...[
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

            if (currentType == '自定义') ...[
              const Text(
                '自定义时间:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _checkInController,
                      decoration: const InputDecoration(
                        labelText: '上班',
                        hintText: '08:30',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _checkOutController,
                      decoration: const InputDecoration(
                        labelText: '下班',
                        hintText: '17:30',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
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
            icon: const Icon(Icons.restore, color: Colors.red),
            label: const Text('恢复默认', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await HapticUtils.mediumImpact();
              widget.onRestore!();
            },
          ),
        TextButton(
          onPressed: () async {
            await HapticUtils.lightImpact();
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            await HapticUtils.mediumImpact();
            final hours = _calculateHours();
            widget.onSave({
              'type': currentType,
              'hours': hours,
              'isOvertime': isOvertime,
              'isManual': true,
              if (currentType == '自定义') ...{
                'customCheckIn': _parseTimeInput(_checkInController.text),
                'customCheckOut': _parseTimeInput(_checkOutController.text),
              },
            });
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
                      color: Colors.black.withOpacity(0.2),
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
                          colors: [Colors.amber[400]!, Colors.orange[400]!],
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
                        color: Colors.orange,
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
                          backgroundColor: Colors.blue,
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
