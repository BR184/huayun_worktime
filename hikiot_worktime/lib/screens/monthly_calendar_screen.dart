import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants/constants.dart';
import '../core/theme/theme.dart';
import '../services/hikiot_api_client.dart';
import '../services/monthly_attendance_repository.dart';
import '../services/storage_service.dart';
import '../services/team_context_service.dart';
import '../services/token_expired_service.dart';
import '../utils/work_time_calculator.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_helper.dart';
import '../utils/target_progress_helper.dart';

import '../widgets/haptic_refresh_indicator.dart';
import '../widgets/precision_text.dart';
import '../widgets/team_selection_dialog.dart';

/// 月度统计页面 - 日历视图
class MonthlyCalendarScreen extends StatefulWidget {
  final String token;
  final bool autoInitialize;

  const MonthlyCalendarScreen({
    super.key,
    required this.token,
    this.autoInitialize = true,
  });

  @override
  MonthlyCalendarScreenState createState() => MonthlyCalendarScreenState();
}

class MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  final HikiotApiClient _apiClient = HikiotApiClient();
  final StorageService _storage = StorageService();
  late final TeamContextService _teamContextService;
  late final MonthlyAttendanceRepository _monthlyRepository;
  bool _isLoading = true;
  String? _error;

  // 防止重复弹出团队选择对话框
  static bool _isShowingTeamDialog = false;

  // 用户信息
  String? _personNo;
  String? _userName;
  String? _teamName;
  String? _teamNo; // 当前团队编号，用于区分不同团队的数据

  // 选中的月份
  DateTime _selectedMonth = DateTime.now();

  // 月度数据: {日期字符串: {工时, 类型, 是否手动, ...}}
  Map<String, Map<String, dynamic>> _monthlyData = {};

  // 节假日计划
  Map<String, String> _holidayPlan = {};

  // 是否包含今日工时数据（适用于第二天上班只打了上班卡想看之前数据的情况）
  bool _includeTodayData = true;

  // 置顶的目标
  int? _pinnedTarget;

  // 智能排序开关
  bool _smartSort = true;

  // 基础目标百分比
  int _baseTarget = 120;

  @override
  void initState() {
    super.initState();
    _apiClient.setToken(widget.token);
    _teamContextService = TeamContextService(
      storage: _storage,
      loadAccountDetail: _apiClient.getAccountDetail,
      changeTeam: _apiClient.changeTeam,
    );
    _monthlyRepository = MonthlyAttendanceRepository(
      storage: _storage,
      loadMonthlyAttendance: _apiClient.getMonthlyAttendance,
      loadDailyAttendance: _apiClient.getDailyAttendance,
    );
    _loadPinnedTarget();
    _loadSmartSort();
    if (widget.autoInitialize) {
      _initializeUser();
    }
  }

  Future<void> initializeUserContext() => _initializeUser();

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

  /// 初始化用户信息
  Future<void> _initializeUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teamContext = await _teamContextService.initialize(
        chooseTeam: _chooseInitialTeam,
      );
      _teamNo = teamContext.teamNo;
      _personNo = teamContext.personNo;
      _teamName = teamContext.teamName;
      _userName =
          teamContext.userName ?? await _storage.loadUserName() ?? '未知用户';

      if (_personNo == null) {
        throw Exception('未找到员工编号');
      }

      // 加载月度数据（只有切换团队时才强制刷新，否则用缓存秒开）
      await _loadMonthlyData(forceRefresh: teamContext.teamChanged);
    } catch (e) {
      // 检查是否是Token失效导致的错误
      if (mounted && TokenExpiredService.isTokenExpiredError(e)) {
        setState(() {
          _isLoading = false;
        });
        await TokenExpiredService.handleTokenExpired(context);
        return;
      }

      setState(() {
        _error = '初始化失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _chooseInitialTeam(
    List<Map<String, dynamic>> teams,
  ) async {
    if (_isShowingTeamDialog) return null;
    _isShowingTeamDialog = true;
    try {
      return await TeamSelectionDialog.show(
        context,
        barrierDismissible: false,
        teams: teams,
      );
    } finally {
      _isShowingTeamDialog = false;
    }
  }

  /// 刷新今日数据（从API获取最新考勤）
  Future<void> refreshTodayData() async {
    // 重新加载智能排序设置
    await _loadSmartSort();

    if (_personNo == null || _teamNo == null) return;

    try {
      final result = await _monthlyRepository.refreshToday(
        teamNo: _teamNo!,
        personNo: _personNo!,
        selectedMonth: _selectedMonth,
        currentData: _monthlyData,
      );

      if (mounted && result.updatedCount > 0) {
        setState(() {
          _monthlyData = result.monthlyData;
          _holidayPlan = result.holidayPlan;
        });
      }
    } catch (e) {
      // 刷新今日数据失败
    }
  }

  /// 刷新指定日期数据（用于每日页切换到月度页时同步当前日期）
  Future<void> refreshDateData(DateTime targetDate) async {
    await _loadSmartSort();

    if (_personNo == null || _teamNo == null) return;

    try {
      final result = await _monthlyRepository.refreshDate(
        teamNo: _teamNo!,
        personNo: _personNo!,
        selectedMonth: _selectedMonth,
        targetDate: targetDate,
        currentData: _monthlyData,
      );

      if (mounted && result.updatedCount > 0) {
        setState(() {
          _monthlyData = result.monthlyData;
          _holidayPlan = result.holidayPlan;
        });
      }
    } catch (e) {
      // 跨页同步失败不阻断页面切换，用户仍可在月度页手动刷新。
      debugPrint('月度指定日期刷新失败: $e');
    }
  }

  /// 从存储刷新显示数据(不调用API,仅重新应用手动标记)
  /// 用于从其他页面返回时同步显示最新的手动修改
  Future<void> refreshFromStorage() async {
    if (_personNo == null || _teamNo == null) return;

    // 重新加载设置（确保智能排序等设置是最新的）
    _smartSort = await _storage.loadSmartSort();
    _pinnedTarget = await _storage.loadPinnedTarget();
    _baseTarget = await _storage.loadBaseTarget();

    if (_monthlyData.isEmpty) {
      await _loadMonthlyData();
      return;
    }

    final result = await _monthlyRepository.refreshFromMarks(
      teamNo: _teamNo!,
      selectedMonth: _selectedMonth,
      currentData: _monthlyData,
      holidayPlan: _holidayPlan,
    );

    if (!mounted) return;
    setState(() {
      _monthlyData = result.monthlyData;
      _holidayPlan = result.holidayPlan;
    });
  }

  /// 加载月度数据 (forceRefresh=true时强制刷新)
  Future<void> _loadMonthlyData({bool forceRefresh = false}) async {
    if (_personNo == null || _teamNo == null) return;

    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _monthlyRepository.loadMonth(
        teamNo: _teamNo!,
        personNo: _personNo!,
        selectedMonth: _selectedMonth,
        forceRefresh: forceRefresh,
      );

      setState(() {
        _monthlyData = result.monthlyData;
        _holidayPlan = result.holidayPlan;
        if (result.personName != null) {
          _userName = result.personName;
        }
        _isLoading = false;
      });

      if (result.source == MonthlyAttendanceLoadSource.persistentCache) {
        final updateTeamNo = _teamNo!;
        final updatePersonNo = _personNo!;
        _monthlyRepository
            .smartQuickUpdateSafely(
              teamNo: updateTeamNo,
              personNo: updatePersonNo,
              selectedMonth: _selectedMonth,
              currentData: result.monthlyData,
            )
            .then((backgroundResult) {
              if (backgroundResult.error != null) {
                debugPrint('月度后台刷新失败: ${backgroundResult.error}');
                return;
              }
              final updateResult = backgroundResult.updateResult;
              if (updateResult == null) return;
              if (!mounted) return;
              if (_teamNo != updateTeamNo || _personNo != updatePersonNo) {
                return;
              }
              if (DateFormat('yyyy-MM').format(_selectedMonth) != monthStr) {
                return;
              }
              setState(() {
                _monthlyData = updateResult.monthlyData;
                _holidayPlan = updateResult.holidayPlan;
              });
            });
      }
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 更新工时数据
  /// [forceAll] = true: 全量更新，调用月度API更新所有日期
  /// [forceAll] = false: 智能快速更新，从今天往前查找，直到找到数据一致的日期
  Future<void> _updateAttendance({required bool forceAll}) async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final result = forceAll
          ? await _monthlyRepository.forceRefreshMonth(
              teamNo: _teamNo!,
              personNo: _personNo!,
              selectedMonth: _selectedMonth,
            )
          : await _monthlyRepository.smartQuickUpdate(
              teamNo: _teamNo!,
              personNo: _personNo!,
              selectedMonth: _selectedMonth,
              currentData: _monthlyData,
              now: now,
            );

      _monthlyData = result.monthlyData;
      _holidayPlan = result.holidayPlan;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              forceAll
                  ? '全量更新完成，共更新 ${result.updatedCount} 天'
                  : result.updatedCount > 0
                  ? '智能更新完成，更新了 ${result.updatedCount} 天'
                  : '数据已是最新，无需更新',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e'), backgroundColor: AppColors.error),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// 公开方法: 静默触发智能更新（用于应用启动时）
  Future<void> smartUpdate() async {
    if (_personNo == null || _teamNo == null) return;
    final result = await _monthlyRepository.smartQuickUpdate(
      teamNo: _teamNo!,
      personNo: _personNo!,
      selectedMonth: _selectedMonth,
      currentData: _monthlyData,
    );

    if (!mounted) return;
    setState(() {
      _monthlyData = result.monthlyData;
      _holidayPlan = result.holidayPlan;
    });
  }

  /// 选择月份
  Future<void> _selectMonth() async {
    HapticUtils.lightImpact(); // 打开月份选择器时震动
    // 使用年月选择器
    int? selectedYear;
    int? selectedMonth;

    final now = DateTime.now();
    final earliestYear = AppConstants.earliestDate.year;
    final earliestMonth = AppConstants.earliestDate.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        selectedYear = _selectedMonth.year;
        selectedMonth = _selectedMonth.month;

        return StatefulBuilder(
          builder: (context, setState) {
            // 生成可选年份列表（从最早年份到当前年份）
            final years = List.generate(
              now.year - earliestYear + 1,
              (index) => earliestYear + index,
            );

            // 生成可选月份列表（根据年份过滤）
            List<int> getAvailableMonths() {
              if (selectedYear == earliestYear && selectedYear == now.year) {
                // 最早年份也是当前年份
                return List.generate(
                  now.month - earliestMonth + 1,
                  (index) => earliestMonth + index,
                );
              } else if (selectedYear == earliestYear) {
                // 最早年份，从最早月份开始
                return List.generate(
                  12 - earliestMonth + 1,
                  (index) => earliestMonth + index,
                );
              } else if (selectedYear == now.year) {
                // 当前年份，到当前月份为止
                return List.generate(now.month, (index) => index + 1);
              } else {
                // 中间年份，全部月份可选
                return List.generate(12, (index) => index + 1);
              }
            }

            final availableMonths = getAvailableMonths();
            // 确保当前选中的月份在可选范围内
            if (!availableMonths.contains(selectedMonth)) {
              selectedMonth = availableMonths.last;
            }

            return AlertDialog(
              title: const Text('选择年月'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 年份选择
                    Row(
                      children: [
                        const Text('年份：', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            items: years.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text('$year年'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              HapticUtils.selectionClick(); // 选择年份时震动
                              setState(() {
                                selectedYear = value;
                                // 重新验证月份
                                final newAvailableMonths = getAvailableMonths();
                                if (!newAvailableMonths.contains(
                                  selectedMonth,
                                )) {
                                  selectedMonth = newAvailableMonths.last;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 月份选择
                    Row(
                      children: [
                        const Text('月份：', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            items: availableMonths.map((month) {
                              return DropdownMenuItem(
                                value: month,
                                child: Text('$month月'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              HapticUtils.selectionClick(); // 选择月份时震动
                              setState(() {
                                selectedMonth = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticUtils.lightImpact();
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    HapticUtils.mediumImpact();
                    Navigator.pop(context);
                    if (selectedYear != null && selectedMonth != null) {
                      this.setState(() {
                        _selectedMonth = DateTime(
                          selectedYear!,
                          selectedMonth!,
                        );
                      });
                      _loadMonthlyData();
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建错误视图
  /// 当检测到可能是 token 过期时，提供重新登录按钮
  Widget _buildErrorView() {
    // 判断是否可能是 token 过期导致的错误
    final isTokenExpired =
        _error != null &&
        (_error!.contains('无法获取账户信息') ||
            _error!.contains('Token') ||
            _error!.contains('token') ||
            _error!.contains('登录') ||
            _error!.contains('999999'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTokenExpired ? Icons.lock_clock : Icons.error_outline,
              size: 72,
              color: isTokenExpired ? AppColors.warning : AppColors.error,
            ),
            const SizedBox(height: 20),
            Text(
              isTokenExpired ? '登录状态已过期' : '加载失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isTokenExpired ? AppColors.warningDark : AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTokenExpired ? '您的登录凭证已过期，请重新登录以继续使用' : _error ?? '未知错误',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            if (!isTokenExpired)
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            const SizedBox(height: 24),
            if (isTokenExpired) ...[
              // Token 过期时显示重新登录按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('重新登录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _initializeUser, child: const Text('再试一次')),
            ] else ...[
              // 其他错误显示重试按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initializeUser,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _goToLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('重新登录'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 跳转到登录页面（使用统一的Token失效处理服务）
  Future<void> _goToLogin() async {
    // 使用TokenExpiredService执行完整的退出登录流程
    await TokenExpiredService.performLogoutAndNavigate(context);

    // 清除本地缓存
    _monthlyRepository.clearCache();
    _apiClient.setToken('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('月度统计')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : HapticRefreshIndicator(
              onRefresh: () => _updateAttendance(forceAll: false),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserCard(),
                    const SizedBox(height: 16),
                    _buildMonthSelector(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    _buildCalendarView(),
                    const SizedBox(height: 16),
                    _buildMonthlyStats(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 用户信息卡片
  Widget _buildUserCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName ?? '未知',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _teamName ?? '未知',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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

  /// 操作按钮区域 - 使用 Android Material 3 按钮并保留触觉反馈
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 第一行: 全量更新 + 快速更新（主要操作按钮）
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await HapticUtils.lightImpact();
                  await _updateAttendance(forceAll: true);
                },
                icon: const Icon(Icons.sync_outlined),
                label: const Text('全量更新'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await HapticUtils.lightImpact();
                  await _updateAttendance(forceAll: false);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('快速更新'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 月份选择器
  Widget _buildMonthSelector() {
    final monthStr = DateFormat('yyyy年MM月').format(_selectedMonth);
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectMonth,
                child: Text(
                  monthStr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (!isCurrentMonth)
              TextButton.icon(
                onPressed: () async {
                  await HapticUtils.selectionClick();
                  setState(() {
                    _selectedMonth = DateTime(now.year, now.month);
                  });
                  await _loadMonthlyData();
                },
                icon: const Icon(Icons.today, size: 18),
                label: const Text('本月'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: _selectMonth,
            ),
          ],
        ),
      ),
    );
  }

  /// 日历视图 (7列网格)
  Widget _buildCalendarView() {
    // 获取当月天数
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday; // 1=周一, 7=周日

    // 今天（工作日）
    final today = DateHelper.getWorkDate();
    final todayStr = DateHelper.formatDate(today);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 日历视图',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 星期标题
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 20),
            // 日历网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: weekdayOfFirstDay - 1 + daysInMonth, // 前面的空白 + 实际天数
              itemBuilder: (context, index) {
                // 前面的空白格子
                if (index < weekdayOfFirstDay - 1) {
                  return const SizedBox.shrink();
                }

                // 实际日期
                final day = index - (weekdayOfFirstDay - 1) + 1;
                final dateStr = DateFormat(
                  'yyyy-MM-dd',
                ).format(DateTime(year, month, day));
                final dayData = _monthlyData[dateStr];
                final hours = dayData?['hours'] ?? 0.0;
                final isToday = dateStr == todayStr;

                // 判断日期类型 (过去/今天/未来)
                final date = DateTime(year, month, day);
                final isPast = date.isBefore(
                  DateTime(today.year, today.month, today.day),
                );
                final isFuture = date.isAfter(
                  DateTime(today.year, today.month, today.day),
                );

                return _buildDayCell(day, hours, isToday, isPast, isFuture);
              },
            ),
            const SizedBox(height: 12),
            // 提示信息
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warningDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '如某天类型/工时有误，点击该日可手动修改',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warningDark,
                      ),
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

  /// 单个日期单元格
  Widget _buildDayCell(
    int day,
    double hours,
    bool isToday,
    bool isPast,
    bool isFuture,
  ) {
    // 获取该日期的数据
    final dateStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(_selectedMonth.year, _selectedMonth.month, day));
    final dayData = _monthlyData[dateStr];
    final dayType = dayData?['type'] ?? AppConstants.typeWorkday;
    final isManual = dayData?['isManual'] ?? false;

    // 根据类型选择背景颜色
    Color bgColor;
    switch (dayType) {
      case '工作日':
        bgColor = AppColors.success;
        break;
      case '加班日':
        bgColor = AppColors.overtime;
        break;
      case '出差':
        bgColor = AppColors.warning;
        break;
      case '请假':
        bgColor = AppColors.error;
        break;
      case '自定义':
        bgColor = AppColors.custom;
        break;
      case '非工作日':
      default:
        bgColor = Colors.grey.shade200;
        break;
    }

    // 透明度
    double opacity = 1.0;
    if (isToday) {
      opacity = 1.0;
    } else if (isPast) {
      opacity = 0.6;
    } else if (isFuture) {
      opacity = 0.15;
    }

    // 文字颜色 - 非工作日用深色文字，其他用白色
    final textColor = (dayType == AppConstants.typeRestDay || opacity < 0.5)
        ? Colors.grey.shade800
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: opacity),
        border: isToday
            ? Border.all(color: AppColors.warning, width: 2)
            : Border.all(color: Colors.grey[300]!, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          HapticUtils.selectionClick(); // 点击日历日期时震动
          _showDetailedDayDialog(dateStr);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (isManual)
                    Container(
                      margin: const EdgeInsets.only(left: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              if (hours > 0)
                PrecisionText(
                  '${WorkTimeCalculator.formatBillableHours(hours)}H',
                  style: TextStyle(fontSize: 10, color: textColor),
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示出差/自定义详细设置对话框
  Future<void> _showDetailedDayDialog(String dateStr) async {
    final dayData = _monthlyData[dateStr];
    if (dayData == null) return;

    String currentType = dayData['type'] ?? AppConstants.typeWorkday;
    bool isOvertime = dayData['isOvertime'] ?? false; // ☀️=正常 🌙=加班
    bool isCustomHours = dayData['isCustomHours'] ?? false; // 是否自定义工时(用于出差)
    String customCheckIn = dayData['customCheckIn'] ?? '09:00';
    String customCheckOut = dayData['customCheckOut'] ?? '18:00';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final checkIn = dayData['checkIn'] as String?;
            final checkOut = dayData['checkOut'] as String?;
            final hours = dayData['hours'] as double? ?? 0.0;
            final hasCrossDayPunch = dayData['hasCrossDayPunch'] == true;

            return AlertDialog(
              title: Text('${dateStr.substring(5)} - $currentType'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 显示打卡时间（如果有工时）
                    if (hours > 0 && (checkIn != null || checkOut != null)) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  Icons.login,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '上班',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  checkIn ?? '--:--',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: checkIn != null
                                        ? AppColors.success
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '下班',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  checkOut ?? '--:--',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: checkOut != null
                                        ? AppColors.warning
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '工时',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                PrecisionText(
                                  '${WorkTimeCalculator.formatHours(hours)}h',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (hasCrossDayPunch) ...[
                      _buildCrossDayPunchDialogReminder(dayData),
                      const SizedBox(height: 16),
                    ],

                    // 类型选择
                    const Text(
                      '类型:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: AppConstants.allWorkTypes.map((type) {
                        final isSelected = currentType == type;

                        // 判断是否应该禁用此按钮
                        final isDisabled =
                            (type == AppConstants.typeOvertime ||
                                type == AppConstants.typeLeave) &&
                            dayData['type'] == AppConstants.typeRestDay &&
                            (dayData['hours'] == null ||
                                dayData['hours'] == 0.0);

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
                            break;
                        }

                        return ChoiceChip(
                          label: Text(
                            type,
                            style: TextStyle(
                              color: isDisabled
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : (isSelected ? Colors.white : Colors.black),
                            ),
                          ),
                          selected: isSelected,
                          backgroundColor: isDisabled
                              ? Colors.grey.withValues(alpha: 0.1)
                              : typeColor.withValues(alpha: 0.3),
                          selectedColor: typeColor,
                          disabledColor: Colors.grey.withValues(alpha: 0.1),
                          onSelected: isDisabled
                              ? null
                              : (selected) {
                                  if (selected) {
                                    HapticUtils.selectionClick(); // 类型选择震动
                                    setDialogState(() {
                                      final previousType = currentType;
                                      currentType = type;

                                      // 如果从非工作日切换到出差/自定义，默认为加班
                                      if ((type ==
                                                  AppConstants
                                                      .typeBusinessTrip ||
                                              type ==
                                                  AppConstants.typeCustom) &&
                                          (previousType ==
                                                  AppConstants.typeRestDay ||
                                              dayData['type'] ==
                                                  AppConstants.typeRestDay)) {
                                        isOvertime = true;
                                      }
                                    });
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 出差/自定义的额外控件
                    if (currentType == AppConstants.typeBusinessTrip ||
                        currentType == AppConstants.typeCustom) ...[
                      Row(
                        children: [
                          const Text(
                            '工时类型:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          ChoiceChip(
                            label: const Text('☀️ 正常'),
                            selected: !isOvertime,
                            onSelected: (selected) {
                              HapticUtils.selectionClick(); // 正常/加班切换震动
                              setDialogState(() {
                                isOvertime = !selected;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('🌙 加班'),
                            selected: isOvertime,
                            onSelected: (selected) {
                              HapticUtils.selectionClick(); // 正常/加班切换震动
                              setDialogState(() {
                                isOvertime = selected;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 出差类型的 工时模式选择 (默认8h / 自定义)
                      if (currentType == AppConstants.typeBusinessTrip) ...[
                        Row(
                          children: [
                            const Text(
                              '工时设置:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            ChoiceChip(
                              label: const Text('默认 8h'),
                              selected: !isCustomHours,
                              onSelected: (selected) {
                                HapticUtils.selectionClick();
                                setDialogState(() {
                                  isCustomHours = !selected;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('自定义'),
                              selected: isCustomHours,
                              onSelected: (selected) {
                                HapticUtils.selectionClick();
                                setDialogState(() {
                                  isCustomHours = selected;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // 自定义类型 或 (出差且开启自定义) 的时间输入
                    if (currentType == AppConstants.typeCustom ||
                        (currentType == AppConstants.typeBusinessTrip &&
                            isCustomHours)) ...[
                      const Text(
                        '自定义时间:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '上班时间',
                          hintText: '08:50 或 0850',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: customCheckIn,
                        onChanged: (value) {
                          customCheckIn = _parseTimeInput(value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '下班时间',
                          hintText: '18:00 或 1800',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: customCheckOut,
                        onChanged: (value) {
                          customCheckOut = _parseTimeInput(value);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '支持格式: 0850, 850, 08:50, 08-50',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                // 取消修改按钮（恢复默认）
                if (dayData['isManual'] == true)
                  TextButton.icon(
                    icon: const Icon(Icons.restore, color: AppColors.error),
                    label: const Text(
                      '恢复默认',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onPressed: () async {
                      HapticUtils.mediumImpact(); // 恢复默认震动
                      await _restoreDefaultType(dateStr);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                  ),
                TextButton(
                  onPressed: () {
                    HapticUtils.lightImpact(); // 取消按钮震动
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    HapticUtils.mediumImpact(); // 保存按钮震动
                    await _saveDaySettings(
                      dateStr,
                      currentType,
                      isOvertime,
                      isCustomHours,
                      customCheckIn,
                      customCheckOut,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCrossDayPunchDialogReminder(Map<String, dynamic> dayData) {
    final punchTime = dayData['crossDayPunchTime'] as String? ?? '凌晨';
    final cutoffTime = DateHelper.getCrossDayTimeString();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.nights_stay, size: 18, color: AppColors.warningDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '检测到 $punchTime 的打卡记录，位于 00:00-$cutoffTime 提醒窗口内。海康接口按自然日返回，请手动设置本日工时。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.warningDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 智能解析时间输入 (支持 0850, 850, 08:50, 08-50)
  String _parseTimeInput(String input) {
    // 移除所有非数字字符
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) return '00:00';

    // 补齐到4位
    String padded = digits.padLeft(4, '0');
    if (padded.length > 4) {
      padded = padded.substring(padded.length - 4);
    }

    // 格式化为 HH:MM
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

  /// 保存日期设置
  Future<void> _saveDaySettings(
    String dateStr,
    String type,
    bool isOvertime,
    bool isCustomHours,
    String customCheckIn,
    String customCheckOut,
  ) async {
    final result = await _monthlyRepository.saveDaySettings(
      teamNo: _teamNo!,
      selectedMonth: _selectedMonth,
      currentData: _monthlyData,
      dateStr: dateStr,
      type: type,
      isOvertime: isOvertime,
      isCustomHours: isCustomHours,
      customCheckIn: customCheckIn,
      customCheckOut: customCheckOut,
    );
    if (!mounted) return;
    setState(() {
      _monthlyData = result.monthlyData;
      _holidayPlan = result.holidayPlan;
    });
  }

  /// 恢复默认类型（从节假日计划）
  Future<void> _restoreDefaultType(String dateStr) async {
    final result = await _monthlyRepository.restoreDefaultType(
      teamNo: _teamNo!,
      selectedMonth: _selectedMonth,
      currentData: _monthlyData,
      holidayPlan: _holidayPlan,
      dateStr: dateStr,
    );
    if (!mounted) return;
    setState(() {
      _monthlyData = result.monthlyData;
      _holidayPlan = result.holidayPlan;
    });
  }

  /// 月度统计汇总
  Widget _buildMonthlyStats() {
    // 第一部分：6类统计(包含未来)
    int workDayCountAll = 0, overtimeDayCountAll = 0, tripDayCountAll = 0;
    int leaveDayCountAll = 0, customDayCountAll = 0, restDayCountAll = 0;
    double workDayHoursAll = 0.0,
        overtimeDayHoursAll = 0.0,
        tripDayHoursAll = 0.0;
    double leaveDayHoursAll = 0.0, customDayHoursAll = 0.0;

    // 第一部分：6类统计(仅到今天)
    int workDayCount = 0, overtimeDayCount = 0;
    int leaveDayCount = 0, restDayCount = 0;
    double workDayHours = 0.0, overtimeDayHours = 0.0, tripDayHours = 0.0;
    double leaveDayHours = 0.0, customDayHours = 0.0;

    // 第二部分：分类统计
    int customNormalCount = 0, customOvertimeCount = 0;
    int tripNormalCount = 0, tripOvertimeCount = 0;
    double customNormalHours = 0.0, customOvertimeHours = 0.0;
    double tripNormalHours = 0.0, tripOvertimeHours = 0.0;

    final today = DateHelper.getWorkDate();
    final currentMonthKey = DateHelper.formatMonth(_selectedMonth);
    final todayKey = DateHelper.formatMonth(today);
    final isCurrentMonth = currentMonthKey == todayKey;

    _monthlyData.forEach((dateStr, data) {
      final date = DateTime.parse(dateStr);
      final type = data['type'] as String;
      // 公司口径百分位不计入：参与累计的每日工时先截断到一位小数，
      // 保证累计值、百分比与日历格内显示口径一致
      final hours = WorkTimeCalculator.billableHours(
        (data['hours'] ?? 0.0) as double,
      );
      final isOvertime = (data['isOvertime'] ?? false) as bool;

      final isFuture = isCurrentMonth && date.isAfter(today);

      // 统计所有(含未来)
      switch (type) {
        case '工作日':
          workDayCountAll++;
          workDayHoursAll += hours;
          break;
        case '加班日':
          overtimeDayCountAll++;
          overtimeDayHoursAll += hours;
          break;
        case '出差':
          tripDayCountAll++;
          tripDayHoursAll += hours;
          break;
        case '请假':
          leaveDayCountAll++;
          leaveDayHoursAll += hours;
          break;
        case '自定义':
          customDayCountAll++;
          customDayHoursAll += hours;
          break;
        case '非工作日':
          restDayCountAll++;
          break;
      }

      // 只统计到今天为止（注意：这里始终包含今日，不受_includeTodayData开关影响）
      // _includeTodayData开关只影响目标进度部分的计算
      if (isFuture) {
        return;
      }

      switch (type) {
        case '工作日':
          workDayCount++;
          workDayHours += hours;
          break;
        case '加班日':
          overtimeDayCount++;
          overtimeDayHours += hours;
          break;
        case '出差':
          tripDayHours += hours;
          if (isOvertime) {
            tripOvertimeCount++;
            tripOvertimeHours += hours;
          } else {
            tripNormalCount++;
            tripNormalHours += hours;
          }
          break;
        case '请假':
          leaveDayCount++;
          leaveDayHours += hours;
          break;
        case '自定义':
          customDayHours += hours;
          if (isOvertime) {
            customOvertimeCount++;
            customOvertimeHours += hours;
          } else {
            customNormalCount++;
            customNormalHours += hours;
          }
          break;
        case '非工作日':
          restDayCount++;
          break;
      }
    });

    // 第二部分计算
    final totalWorkDays =
        workDayCount + customNormalCount + tripNormalCount + leaveDayCount;
    final totalOvertimeDays =
        overtimeDayCount + customOvertimeCount + tripOvertimeCount;
    final totalRestDays = restDayCount;
    final totalWorkHours = workDayHours + customNormalHours + tripNormalHours;
    final totalOvertimeHours =
        overtimeDayHours + customOvertimeHours + tripOvertimeHours;

    // 计算整月的总天数(含未来)
    int totalWorkDaysAll = 0;
    int totalOvertimeDaysAll = 0;
    int totalRestDaysAll = 0;

    _monthlyData.forEach((dateStr, data) {
      final type = data['type'] as String;
      final isOvertime = (data['isOvertime'] ?? false) as bool;

      if (type == AppConstants.typeWorkday ||
          type == AppConstants.typeLeave ||
          (type == AppConstants.typeCustom && !isOvertime) ||
          (type == AppConstants.typeBusinessTrip && !isOvertime)) {
        totalWorkDaysAll++;
      } else if (type == AppConstants.typeOvertime ||
          (type == AppConstants.typeCustom && isOvertime) ||
          (type == AppConstants.typeBusinessTrip && isOvertime)) {
        totalOvertimeDaysAll++;
      } else if (type == AppConstants.typeRestDay) {
        totalRestDaysAll++;
      }
    });

    final totalHours =
        workDayHours +
        overtimeDayHours +
        tripDayHours +
        leaveDayHours +
        customDayHours;
    final avgHours = totalWorkDays > 0
        ? (totalWorkHours + totalOvertimeHours) / totalWorkDays
        : 0.0;

    // 计算包含今天的统计
    final totalHoursWithToday = totalWorkHours + totalOvertimeHours;
    final percentageWithToday = WorkTimeCalculator.calculatePercentage(
      hours: totalHoursWithToday,
      baseHours: totalWorkDays * 8.0,
    );

    // 计算排除今天的统计（只在当前月份有效）
    double totalHoursExcludingToday = totalHoursWithToday;
    int totalWorkDaysExcludingToday = totalWorkDays;
    if (isCurrentMonth) {
      final todayStr = DateHelper.formatDate(today);
      final todayData = _monthlyData[todayStr];
      if (todayData != null) {
        final todayType = todayData['type'] as String;
        // 减除今日工时须与累计口径一致（百分位不计入）
        final todayHours = WorkTimeCalculator.billableHours(
          (todayData['hours'] ?? 0.0) as double,
        );
        final todayIsOvertime = (todayData['isOvertime'] ?? false) as bool;

        // 从总工时中减去今天的工时
        if (todayType == AppConstants.typeWorkday ||
            todayType == AppConstants.typeLeave) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeOvertime) {
          totalHoursExcludingToday -= todayHours;
        } else if (todayType == AppConstants.typeCustom && !todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeCustom && todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
        } else if (todayType == AppConstants.typeBusinessTrip &&
            !todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeBusinessTrip &&
            todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
        }
      }
    }
    final percentageExcludingToday = WorkTimeCalculator.calculatePercentage(
      hours: totalHoursExcludingToday,
      baseHours: totalWorkDaysExcludingToday * 8.0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
                SizedBox(width: 8),
                Text(
                  '月度统计',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 24),

            // 第一部分：6类统计
            const Text(
              '按类型统计',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildTypeChip(
                  AppConstants.typeWorkday,
                  workDayCountAll,
                  workDayHoursAll,
                  AppColors.workday,
                ),
                _buildTypeChip(
                  AppConstants.typeOvertime,
                  overtimeDayCountAll,
                  overtimeDayHoursAll,
                  AppColors.overtime,
                ),
                _buildTypeChip(
                  AppConstants.typeBusinessTrip,
                  tripDayCountAll,
                  tripDayHoursAll,
                  AppColors.businessTrip,
                ),
                _buildTypeChip(
                  AppConstants.typeLeave,
                  leaveDayCountAll,
                  leaveDayHoursAll,
                  AppColors.leave,
                ),
                _buildTypeChip(
                  AppConstants.typeCustom,
                  customDayCountAll,
                  customDayHoursAll,
                  AppColors.custom,
                ),
                _buildTypeChip('休息', restDayCountAll, 0.0, AppColors.restDay),
              ],
            ),

            const Divider(height: 24),

            // 第二部分:详细分类
            Row(
              children: [
                const Text(
                  '详细统计',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticUtils.lightImpact(); // 帮助图标点击震动
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('统计规则说明'),
                        content: const Text(
                          '总工作日包含:\n'
                          '• 工作日\n'
                          '• 自定义-正常\n'
                          '• 出差-正常\n'
                          '• 请假\n\n'
                          '注意:请假虽然是休息日，但在工时计算属于上了0小时的一天，不属于休息日，因此计入工作日天数。\n\n'
                          '总加班日包含:\n'
                          '• 加班日\n'
                          '• 自定义-加班\n'
                          '• 出差-加班',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              HapticUtils.lightImpact();
                              Navigator.pop(context);
                            },
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  '总工作日',
                  '$totalWorkDays天/$totalWorkDaysAll天\n${WorkTimeCalculator.formatHours(totalWorkHours)}h',
                  AppColors.workday,
                ),
                _buildStatColumn(
                  '总加班日',
                  '$totalOvertimeDays天/$totalOvertimeDaysAll天\n${WorkTimeCalculator.formatHours(totalOvertimeHours)}h',
                  AppColors.overtime,
                ),
                _buildStatColumn(
                  '总休息日',
                  '$totalRestDays天/$totalRestDaysAll天',
                  AppColors.restDay,
                ),
              ],
            ),

            const Divider(height: 24),

            // 汇总统计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '总工时',
                  WorkTimeCalculator.formatHours(totalHours),
                  '小时',
                  AppColors.primary,
                ),
                _buildStatItem(
                  '日均工时',
                  WorkTimeCalculator.formatHours(avgHours),
                  '小时/天',
                  AppColors.accent,
                ),
              ],
            ),

            const Divider(height: 32),

            // 第三部分：工时百分比和进度条
            const Text(
              '工时完成度',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 包含今天和排除今天的百分比
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPercentageCard(
                  isCurrentMonth ? '本月完成率' : '当月完成率',
                  percentageWithToday,
                  isCurrentMonth ? '含今日' : '',
                  totalWorkDays,
                  totalHoursWithToday,
                ),
                if (isCurrentMonth && totalWorkDaysExcludingToday > 0)
                  _buildPercentageCard(
                    '截至昨日',
                    percentageExcludingToday,
                    '不含今日',
                    totalWorkDaysExcludingToday,
                    totalHoursExcludingToday,
                  ),
              ],
            ),

            // 当月显示：截至今日需完成的目标时长
            if (isCurrentMonth && totalWorkDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PrecisionText(
                  '达成$_baseTarget%目标，今日需 ${WorkTimeCalculator.formatHours(totalWorkDays * 8.0 * _baseTarget / 100)}h，截至昨日需 ${WorkTimeCalculator.formatHours(totalWorkDaysExcludingToday * 8.0 * _baseTarget / 100)}h',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 16),

            // 多档位进度条
            _buildProgressGoals(
              totalWorkDays,
              totalHoursWithToday,
              isCurrentMonth,
              _monthlyData, // 传入完整数据用于计算总工作日
            ),
          ],
        ),
      ),
    );
  }

  /// 百分比卡片
  Widget _buildPercentageCard(
    String title,
    double percentage,
    String subtitle,
    int days,
    double hours,
  ) {
    final targetHours = days * 8; // 100%目标工时
    final isCompleted = percentage >= _baseTarget;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.successLight : AppColors.warningLight,
          borderRadius: AppDimens.borderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              PrecisionText(
                '${WorkTimeCalculator.formatHours(percentage)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isCompleted
                      ? AppColors.successDark
                      : AppColors.warningDark,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 8),
              PrecisionText(
                '${WorkTimeCalculator.formatHours(hours)}h / ${WorkTimeCalculator.formatHours(targetHours)}h',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 多档位进度目标
  Widget _buildProgressGoals(
    int totalWorkDaysUpToToday,
    double totalHours,
    bool isCurrentMonth,
    Map<String, dynamic> monthlyData,
  ) {
    // 历史月份不显示目标进度
    if (!isCurrentMonth) {
      return const SizedBox.shrink();
    }

    if (totalWorkDaysUpToToday == 0) {
      return const SizedBox.shrink();
    }

    final today = DateTime.now();
    final todayDateStr = DateFormat('yyyy-MM-dd').format(today);

    // 根据"含今日"开关重新计算工时和工作日数
    double adjustedTotalHours = totalHours;
    int adjustedTotalWorkDays = totalWorkDaysUpToToday;
    bool todayIsWorkDay = false; // 记录今天是否是工作日

    if (isCurrentMonth) {
      final todayData = monthlyData[todayDateStr];
      if (todayData != null) {
        final type = todayData['type'] as String;
        final hours = (todayData['hours'] ?? 0.0) as double;
        todayIsWorkDay =
            type == AppConstants.typeWorkday ||
            type == AppConstants.typeLeave ||
            (type == AppConstants.typeCustom &&
                !(todayData['isOvertime'] ?? false)) ||
            (type == AppConstants.typeBusinessTrip &&
                !(todayData['isOvertime'] ?? false));

        // 如果开关关闭，需要排除今日数据
        if (!_includeTodayData && todayIsWorkDay) {
          adjustedTotalHours -= hours;
          adjustedTotalWorkDays -= 1;
        }
      }
    }

    // 计算整月的总工作日(包括未来)
    int totalWorkDaysInMonth = 0;
    int remainingWorkDays = 0; // 剩余工作日（根据开关决定是否包含今天）

    if (isCurrentMonth) {
      final lastDay = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayData = monthlyData[dateStr];
        if (dayData != null) {
          final type = dayData['type'] as String;
          final isWorkDay =
              type == AppConstants.typeWorkday ||
              type == AppConstants.typeLeave ||
              (type == AppConstants.typeCustom &&
                  !(dayData['isOvertime'] ?? false)) ||
              (type == AppConstants.typeBusinessTrip &&
                  !(dayData['isOvertime'] ?? false));

          if (isWorkDay) {
            totalWorkDaysInMonth++;
            // 计算剩余工作日（用于计算每日需工作多少小时来达成目标）
            if (_includeTodayData) {
              // 含今日：今日工时已计入，所以剩余工作日=明天及以后
              if (date.day > today.day) {
                remainingWorkDays++;
              }
            } else {
              // 不含今日：今日工时未计入，所以剩余工作日=今天及以后
              if (date.day >= today.day) {
                remainingWorkDays++;
              }
            }
          }
        }
      }
    } else {
      // 历史月份,使用已统计的天数
      totalWorkDaysInMonth = adjustedTotalWorkDays;
      remainingWorkDays = 0;
    }

    final baseHours = totalWorkDaysInMonth * 8;

    // 计算日均工时（使用调整后的数据）
    final avgHoursPerDay = adjustedTotalWorkDays > 0
        ? adjustedTotalHours / adjustedTotalWorkDays
        : 0.0;
    final targetProgress = TargetProgressHelper.buildMonthlyProgress(
      adjustedTotalHours: adjustedTotalHours,
      baseHours: baseHours.toDouble(),
      avgHoursPerDay: avgHoursPerDay,
      remainingWorkDays: remainingWorkDays,
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
            // 今日数据开关
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '含今日',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _includeTodayData,
                    onChanged: (value) async {
                      await HapticUtils.selectionClick();
                      setState(() {
                        _includeTodayData = value;
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sortedTargetData.map((data) {
          final target = data['target'] as int;
          final targetHours = data['targetHours'] as double;
          final isCompleted = data['isCompleted'] as bool;
          final avgCompleted = data['avgCompleted'] as bool;
          final gapHours = data['gapHours'] as double;
          final dailyNeed = data['dailyNeed'] as double;
          final avgHoursPerDay = data['avgHoursPerDay'] as double;
          final targetAvgHours = data['targetAvgHours'] as double;
          final avgProgress = data['avgProgress'] as double;

          // 判断是否是特殊标记的目标
          final isHighestAchieved = target == highestAchievedTarget;
          final isNextToAchieve = target == nextToAchieveTarget;

          // 基础目标（可配置，默认120%）
          final isBaseTarget = target == _baseTarget;

          // 日均+总进度都完成的折叠显示
          if (isCompleted && avgCompleted) {
            return _buildCollapsedGoal(
              target,
              adjustedTotalHours,
              targetHours,
              isBaseTarget: isBaseTarget,
            );
          }

          // 未完成的展开显示（包括基础目标）
          return _buildExpandedGoal(
            target,
            adjustedTotalHours,
            targetHours,
            gapHours,
            dailyNeed,
            remainingWorkDays,
            isCompleted,
            isBaseTarget,
            avgHoursPerDay,
            targetAvgHours,
            avgProgress,
            adjustedTotalWorkDays,
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
    double gapHours,
    double dailyNeed,
    int remainingDays,
    bool isCompleted,
    bool isBaseTarget,
    double avgHoursPerDay,
    double targetAvgHours,
    double avgProgress,
    int totalWorkDaysUpToToday, {
    bool isHighestAchieved = false,
    bool isNextToAchieve = false,
  }) {
    final progressPercentage = WorkTimeCalculator.calculatePercentage(
      hours: currentHours,
      baseHours: targetHours,
      min: 0,
      max: 100,
    );
    final progress = progressPercentage / 100;
    final avgProgressPercentage = WorkTimeCalculator.billableHours(
      (avgProgress * 100).clamp(0.0, 100.0),
    );

    Color getProgressColor() {
      if (isCompleted) return AppColors.success;
      if (isBaseTarget) return AppColors.warning;
      return AppColors.primary;
    }

    Color getAvgProgressColor() {
      if (avgProgress >= 1.0) return AppColors.success;
      if (isBaseTarget) return AppColors.warning;
      return AppColors.overtime;
    }

    // 特殊标记的边框颜色
    Color? getBorderColor() {
      if (isHighestAchieved) return AppColors.success; // 绿色 - 最高达成
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
                  // 置顶标签优先显示
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
                  // 特殊标记标签(置顶时不显示)
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

              // 总进度条
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '总进度',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PrecisionText(
                        '${WorkTimeCalculator.formatHours(progressPercentage)}%',
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

              const SizedBox(height: 8),

              // 平均进度条
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '日均进度',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PrecisionText(
                        '${WorkTimeCalculator.formatHours(avgProgressPercentage)}% (${WorkTimeCalculator.formatHours(avgHoursPerDay)}h/天)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: getAvgProgressColor(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: avgProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getAvgProgressColor(),
                    ),
                    minHeight: 6,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 提示信息
              PrecisionText(
                remainingDays > 0
                    ? '还需 ${WorkTimeCalculator.formatHours(gapHours)}h，每天需上 ${WorkTimeCalculator.formatHours(dailyNeed)}h'
                    : '还需 ${WorkTimeCalculator.formatHours(gapHours)}h (本月已无工作日)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 类型芯片
  Widget _buildTypeChip(String label, int count, double hours, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: PrecisionText(
        '$label: $count天 ${hours > 0 ? "${WorkTimeCalculator.formatHours(hours)}h" : ""}',
        style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9)),
      ),
    );
  }

  /// 统计列
  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        PrecisionText(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 统计项
  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PrecisionText(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
