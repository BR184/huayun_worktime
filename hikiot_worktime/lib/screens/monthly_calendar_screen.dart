import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/constants.dart';
import '../core/theme/theme.dart';
import '../services/hikiot_api_client.dart';
import '../services/storage_service.dart';
import '../services/token_expired_service.dart';
import '../utils/work_time_calculator.dart';
import '../utils/attendance_parser.dart';
import '../utils/haptic_utils.dart';
import '../utils/date_helper.dart';
import '../utils/smart_day_type_helper.dart';

import '../utils/holiday_utils.dart'; // [NEW] Import
import '../widgets/home_button.dart';
import '../widgets/haptic_refresh_indicator.dart';

/// 月度统计页面 - 日历视图
class MonthlyCalendarScreen extends StatefulWidget {
  final String token;

  const MonthlyCalendarScreen({super.key, required this.token});

  @override
  MonthlyCalendarScreenState createState() => MonthlyCalendarScreenState();
}

class MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  final HikiotApiClient _apiClient = HikiotApiClient();
  final StorageService _storage = StorageService();
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

  // 已加载的月份缓存 (格式: "YYYY-MM" -> Map<String, Map<String, dynamic>>)
  final Map<String, Map<String, Map<String, dynamic>>> _monthlyDataCache = {};

  // 已锁定的日期(这些日期的工时不会再更新,除非强制)
  final Set<String> _lockedDates = {};

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
    _loadPinnedTarget();
    _loadSmartSort();
    _initializeUser();
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

  /// 生成目标列表，确保包含基础目标
  List<int> _generateTargetList(int baseTarget) {
    return WorkTimeCalculator.generateTargetList(baseTarget);
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
      // 获取账户信息
      final accountDetail = await _apiClient.getAccountDetail();
      if (accountDetail == null) {
        // Token失效，直接弹出对话框引导用户重新登录
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await TokenExpiredService.handleTokenExpired(context);
          return;
        }
        throw Exception('无法获取账户信息');
      }

      final teamInfoList = accountDetail['teamInfoList'] as List<dynamic>?;
      if (teamInfoList == null || teamInfoList.isEmpty) {
        throw Exception('该账号没有关联任何团队');
      }

      // 检查是否有多个团队，需要用户选择
      Map<String, dynamic> selectedTeam;
      bool isTeamChanged = false; // 标记是否切换了团队

      if (teamInfoList.length > 1) {
        // 先尝试从本地加载上次选择的团队
        final savedTeamNo = await _storage.loadSelectedTeam();

        if (savedTeamNo != null) {
          // 在团队列表中查找保存的团队
          final savedTeam = teamInfoList.firstWhere(
            (team) => team['teamNo'] == savedTeamNo,
            orElse: () => null,
          );

          if (savedTeam != null) {
            // 找到保存的团队,直接使用
            selectedTeam = savedTeam as Map<String, dynamic>;
          } else {
            // 保存的团队不在列表中,显示选择对话框
            if (_isShowingTeamDialog) {
              // 已有对话框在显示，使用默认团队
              selectedTeam = teamInfoList[0] as Map<String, dynamic>;
            } else {
              selectedTeam =
                  await _showTeamSelectionDialog(teamInfoList) ??
                  teamInfoList[0] as Map<String, dynamic>;
            }
            isTeamChanged = true;
          }
        } else {
          // 没有保存记录,显示团队选择对话框
          if (_isShowingTeamDialog) {
            // 已有对话框在显示，使用默认团队
            selectedTeam = teamInfoList[0] as Map<String, dynamic>;
          } else {
            selectedTeam =
                await _showTeamSelectionDialog(teamInfoList) ??
                teamInfoList[0] as Map<String, dynamic>;
          }
          isTeamChanged = true;
        }
      } else {
        selectedTeam = teamInfoList[0] as Map<String, dynamic>;
        // 检查是否与上次相同
        final savedTeamNo = await _storage.loadSelectedTeam();
        isTeamChanged = savedTeamNo != selectedTeam['teamNo'];
      }

      final teamNo = selectedTeam['teamNo'] as String?;
      if (teamNo == null) {
        throw Exception('团队信息不完整');
      }

      // 切换团队激活Token
      final teamChanged = await _apiClient.changeTeam(teamNo);
      if (!teamChanged) {
        throw Exception('切换团队失败');
      }

      // 保存团队编号
      _teamNo = teamNo;
      _personNo = selectedTeam['personNo'] as String?;

      // 保存teamNo和personNo到SharedPreferences供其他页面使用
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teamNo', teamNo);
      if (_personNo != null) {
        await prefs.setString('personNo', _personNo!);
      }

      // 先从本地加载已保存的用户名
      _userName = await _storage.loadUserName();
      // 如果没有保存的，使用nickName
      if (_userName == null || _userName!.isEmpty) {
        _userName = accountDetail['nickName'] as String? ?? '未知用户';
      }
      _teamName = selectedTeam['teamName'] as String? ?? '未知团队';

      _teamName = selectedTeam['teamName'] as String? ?? '未知团队';

      if (_personNo == null) {
        throw Exception('未找到员工编号');
      }

      // 保存选择的团队到本地
      await _storage.saveSelectedTeam(teamNo);

      // 加载月度数据（只有切换团队时才强制刷新，否则用缓存秒开）
      await _loadMonthlyData(forceRefresh: isTeamChanged);
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

  /// 显示团队选择对话框
  Future<Map<String, dynamic>?> _showTeamSelectionDialog(
    List<dynamic> teams,
  ) async {
    // 防止重复显示
    if (_isShowingTeamDialog) {
      return null;
    }
    _isShowingTeamDialog = true;

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
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
                  return ListTile(
                    title: Text(teamName),
                    onTap: () {
                      HapticUtils.selectionClick(); // 选择团队震动
                      Navigator.of(context).pop(team);
                    },
                  );
                },
              ),
            ),
          );
        },
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

    final workDate = DateHelper.getWorkDate();
    // 只在查看当前月份时刷新
    if (_selectedMonth.year != workDate.year ||
        _selectedMonth.month != workDate.month) {
      return;
    }

    try {
      final todayStr = DateHelper.formatDate(workDate);
      final data = await _apiClient.getDailyAttendance(todayStr, _personNo!);

      if (data != null && mounted) {
        // 使用统一的解析器
        final attendance = AttendanceParser.parseFromResponse(data);

        // 更新今日数据
        if (_monthlyData.containsKey(todayStr)) {
          final savedMarks = await _storage.loadCalendarMarks(_teamNo!);
          final isManual = savedMarks[todayStr]?['isManual'] ?? false;

          // 只有非手动标记的才更新工时
          if (!isManual) {
            setState(() {
              _monthlyData[todayStr]!['hours'] = attendance.hours;
              _monthlyData[todayStr]!['checkIn'] = attendance.checkIn;
              _monthlyData[todayStr]!['checkOut'] = attendance.checkOut;

              // 使用统一工具类处理智能类型
              final newType = SmartDayTypeHelper.inferDayType(
                currentType: _monthlyData[todayStr]!['type'],
                hours: attendance.hours,
                dateStr: todayStr,
                isManual: false,
                hasCheckIn: attendance.hasValidData,
              );
              if (newType != null) {
                _monthlyData[todayStr]!['type'] = newType;
              }
            });

            // 同步更新缓存
            final monthKey =
                '${_teamNo}_${DateHelper.formatMonth(_selectedMonth)}';
            if (_monthlyDataCache.containsKey(monthKey)) {
              _monthlyDataCache[monthKey]![todayStr]!['hours'] =
                  attendance.hours;
              _monthlyDataCache[monthKey]![todayStr]!['checkIn'] =
                  attendance.checkIn;
              _monthlyDataCache[monthKey]![todayStr]!['checkOut'] =
                  attendance.checkOut;
            }
          }
        }
      }
    } catch (e) {
      // 刷新今日数据失败
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

    final monthKey =
        '${_teamNo}_${DateFormat('yyyy-MM').format(_selectedMonth)}';

    // 重新加载手动标记
    final savedMarks = await _storage.loadCalendarMarks(_teamNo!);

    // 如果当前月份有缓存数据,重新应用手动标记
    if (_monthlyDataCache.containsKey(monthKey)) {
      setState(() {
        // 先从缓存恢复原始数据
        _monthlyData = {};
        _monthlyDataCache[monthKey]!.forEach((dateStr, data) {
          _monthlyData[dateStr] = Map<String, dynamic>.from(data);
        });

        // 重新应用手动标记
        savedMarks.forEach((dateStr, markData) {
          if (_monthlyData.containsKey(dateStr)) {
            final data = _monthlyData[dateStr]!;
            data['type'] = markData['type'] ?? data['type'];
            data['isManual'] = markData['isManual'] ?? false;
            data['isOvertime'] = markData['isOvertime'] ?? false;

            // 根据类型计算工时
            if (markData['type'] == AppConstants.typeCustom) {
              data['customCheckIn'] = markData['customCheckIn'] ?? '09:00';
              data['customCheckOut'] = markData['customCheckOut'] ?? '18:00';
              data['hours'] = _calculateCustomHours(
                data['customCheckIn'] as String,
                data['customCheckOut'] as String,
              );
            } else if (markData['type'] == AppConstants.typeBusinessTrip) {
              if (markData['isCustomHours'] == true) {
                 data['isCustomHours'] = true;
                 data['customCheckIn'] = markData['customCheckIn'] ?? '09:00';
                 data['customCheckOut'] = markData['customCheckOut'] ?? '18:00';
                 data['hours'] = _calculateCustomHours(
                   data['customCheckIn'] as String,
                   data['customCheckOut'] as String,
                 );
              } else {
                 data['hours'] = 8.0;
                 data['isCustomHours'] = false;
              }
            } else if (markData['type'] == AppConstants.typeLeave) {
              data['hours'] = 0.0;
            }
            // 其他类型保持 API 原始工时（已在上面恢复）
          }
        });

        // 处理已被删除的手动标记（恢复默认）
        _monthlyData.forEach((dateStr, data) {
          if (data['isManual'] == true && !savedMarks.containsKey(dateStr)) {
            // 手动标记已被删除，恢复为默认类型和API工时
            // 从节假日计划获取默认类型
            final date = DateTime.parse(dateStr);
            final defaultType =
                _holidayPlan[dateStr] ?? (date.weekday <= 5 ? AppConstants.typeWorkday : AppConstants.typeRestDay);

            data['type'] = defaultType;
            data['hours'] = data['apiHours'] ?? 0.0;
            data['isManual'] = false;
            data.remove('isOvertime');
            data.remove('customCheckIn');
            data.remove('customCheckOut');
          }
        });
      });
    } else {
      // 没有缓存，重新加载
      await _loadMonthlyData();
    }
  }

  /// 加载月度数据 (forceRefresh=true时强制刷新)
  Future<void> _loadMonthlyData({bool forceRefresh = false}) async {
    if (_personNo == null || _teamNo == null) return;

    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final monthKey = '${_teamNo}_$monthStr'; // 按团队和月份区分缓存

    // 检查内存缓存
    if (!forceRefresh && _monthlyDataCache.containsKey(monthKey)) {
      setState(() {
        _monthlyData = _monthlyDataCache[monthKey]!;
        _isLoading = false;
      });
      return;
    }

    // 尝试从本地持久化缓存加载（秒开）
    if (!forceRefresh) {
      final cachedData = await _storage.loadMonthlyData(_teamNo!, monthStr);
      if (cachedData != null) {
        // 应用智能日期类型（修复缓存数据未应用智能逻辑的问题）
        SmartDayTypeHelper.applyToMonthlyData(cachedData);
        setState(() {
          _monthlyData = cachedData;
          _monthlyDataCache[monthKey] = cachedData;
          _isLoading = false;
        });
        // 后台静默智能更新
        _smartQuickUpdate().then((_) {
          // 更新完保存到本地
          _storage.saveMonthlyData(_teamNo!, monthStr, _monthlyData);
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 加载节假日计划 (仅从本地加载，由 API 刷新时自动同步)
      var yearHolidayPlan = await _storage.getHolidayPlan(_selectedMonth.year);

      if (yearHolidayPlan.isEmpty) {
        // 本地没有任何年份数据时使用默认规则
        yearHolidayPlan = _storage.generateDefaultPlan(
          _selectedMonth.year,
          _selectedMonth.month,
        );
      }

      _holidayPlan = yearHolidayPlan;

      // 2. 加载API数据
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      final monthlyStats = await _apiClient.getMonthlyAttendance(
        monthStr,
        _personNo!,
      );

      if (monthlyStats == null) {
        throw Exception('获取月度数据失败');
      }

      // 提取并保存用户姓名（如果有）
      final personName = monthlyStats['personName'] as String?;
      if (personName != null && personName.isNotEmpty) {
        _userName = personName;
        await _storage.saveUserName(personName);
      }

      // 3. 加载本地标记（按团队区分）
      final savedMarks = await _storage.loadCalendarMarks(_teamNo!);

      // 4. 转换数据格式并合并
      final Map<String, Map<String, dynamic>> dataMap = {};
      final dailyRecords = monthlyStats['dailyRecords'] as List<dynamic>? ?? [];

      // 先填充整个月的默认数据
      final daysInMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      ).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final dateStr = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(_selectedMonth.year, _selectedMonth.month, day));

        // 从节假日计划获取默认类型
        final defaultType =
            _holidayPlan[dateStr] ??
            (DateTime(_selectedMonth.year, _selectedMonth.month, day).weekday <=
                    5
                ? AppConstants.typeWorkday
                : AppConstants.typeRestDay);

        dataMap[dateStr] = {
          'hours': 0.0,
          'checkIn': null,
          'checkOut': null,
          'isLate': false,
          'isEarlyLeave': false,
          'type': defaultType,
          'isManual': false,
        };
      }

      // 再填充API返回的打卡数据
      bool holidayPlanChanged = false;
      for (var record in dailyRecords) {
        final date = record['date'] as String;
        final hours = record['hours'] ?? 0.0;
        final isRestDay = record['isRestDay'] ?? false;

        // 1. 同步海康原生日历类型
        if (dataMap.containsKey(date)) {
          final newNativeType = HolidayUtils.determineNativeType(
            isRestDay: isRestDay,
            currentType: dataMap[date]!['type'],
            isManual: dataMap[date]!['isManual'] == true,
          );

          if (newNativeType != null) {
            dataMap[date]!['type'] = newNativeType;
            _holidayPlan[date] = newNativeType;
            holidayPlanChanged = true;
          }
        }

        dataMap[date] = {
          ...dataMap[date]!,
          'hours': hours,
          'apiHours': hours, // 保存API原始工时，用于取消修改时恢复
          'checkIn': record['checkIn'],
          'checkOut': record['checkOut'],
          'isLate': record['isLate'] ?? false,
          'isEarlyLeave': record['isEarlyLeave'] ?? false,
        };

        // 统一使用 SmartDayTypeHelper 进行智能类型推断
        final checkInStr = record['checkIn'] as String?;
        final hasCheckIn = checkInStr != null && checkInStr.isNotEmpty && checkInStr != '-';

        final newType = SmartDayTypeHelper.inferDayType(
          currentType: dataMap[date]!['type'],
          hours: hours,
          dateStr: date,
          isManual: dataMap[date]!['isManual'] ?? false,
          hasCheckIn: hasCheckIn,
        );

        if (newType != null) {
          dataMap[date]!['type'] = newType;
        }
      }

      // 异步保存更新后的节假日计划
      if (holidayPlanChanged) {
        _storage.saveHolidayPlan(_selectedMonth.year, _holidayPlan);
      }

      // 最后应用用户的手动标记（覆盖）
      savedMarks.forEach((dateStr, mark) {
        if (dataMap.containsKey(dateStr)) {
          dataMap[dateStr]!['type'] = mark['type'] ?? dataMap[dateStr]!['type'];
          dataMap[dateStr]!['isManual'] = true;

          // 恢复isOvertime标记
          if (mark['isOvertime'] != null) {
            dataMap[dateStr]!['isOvertime'] = mark['isOvertime'];
          }

          // 如果是自定义类型，恢复自定义时间和工时
          if (mark['type'] == AppConstants.typeCustom) {
            if (mark['customCheckIn'] != null) {
              dataMap[dateStr]!['customCheckIn'] = mark['customCheckIn'];
            }
            if (mark['customCheckOut'] != null) {
              dataMap[dateStr]!['customCheckOut'] = mark['customCheckOut'];
            }
            // 重新计算自定义工时
            if (mark['customCheckIn'] != null &&
                mark['customCheckOut'] != null) {
              dataMap[dateStr]!['hours'] = _calculateCustomHours(
                mark['customCheckIn'] as String,
                mark['customCheckOut'] as String,
              );
            }
            } else if (mark['type'] == AppConstants.typeBusinessTrip) {
              // 出差类型: 支持默认8小时或自定义
              if (mark['isCustomHours'] == true) {
                 dataMap[dateStr]!['isCustomHours'] = true;
                 if (mark['customCheckIn'] != null) {
                   dataMap[dateStr]!['customCheckIn'] = mark['customCheckIn'];
                 }
                 if (mark['customCheckOut'] != null) {
                   dataMap[dateStr]!['customCheckOut'] = mark['customCheckOut'];
                 }
                 if (dataMap[dateStr]!['customCheckIn'] != null &&
                     dataMap[dateStr]!['customCheckOut'] != null) {
                   dataMap[dateStr]!['hours'] = _calculateCustomHours(
                     dataMap[dateStr]!['customCheckIn'],
                     dataMap[dateStr]!['customCheckOut'],
                   );
                 }
              } else {
                 dataMap[dateStr]!['hours'] = 8.0;
                 dataMap[dateStr]!['isCustomHours'] = false;
              }
            }
        }
      });

      setState(() {
        _monthlyData = dataMap;
        // 保存到内存缓存
        _monthlyDataCache[monthKey] = Map<String, Map<String, dynamic>>.from(
          dataMap.map(
            (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
          ),
        );
        _isLoading = false;
      });

      // 保存到本地持久化缓存
      await _storage.saveMonthlyData(_teamNo!, monthStr, dataMap);
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
      final today = DateFormat('yyyy-MM-dd').format(now);
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      int updatedCount = 0;

      if (forceAll) {
        // 强制更新全部: 调用月度API,更新所有日期
        final monthlyStats = await _apiClient.getMonthlyAttendance(
          monthStr,
          _personNo!,
        );

        if (monthlyStats == null) {
          throw Exception('获取月度数据失败');
        }

        final dailyRecords =
            monthlyStats['dailyRecords'] as List<dynamic>? ?? [];

        for (var record in dailyRecords) {
          final date = record['date'] as String;

          if (_monthlyData.containsKey(date)) {
            final hours = record['hours'] ?? 0.0;
            _monthlyData[date]!['hours'] = hours;
            _monthlyData[date]!['apiHours'] = hours;
            _monthlyData[date]!['checkIn'] = record['checkIn'];
            _monthlyData[date]!['checkOut'] = record['checkOut'];
            _monthlyData[date]!['isLate'] = record['isLate'] ?? false;
            _monthlyData[date]!['isEarlyLeave'] =
                record['isEarlyLeave'] ?? false;

            // 强制更新会重新锁定过去的日期
            if (date != today) {
              _lockedDates.add(date);
            }

            updatedCount++;
          }
        }
      } else {
        // 智能快速更新: 从今天往前查找，直到找到数据一致的日期
        updatedCount = await _smartQuickUpdate();
      }

      // 更新内存缓存
      final monthKey = '${_teamNo}_$monthStr';
      _monthlyDataCache[monthKey] = Map<String, Map<String, dynamic>>.from(
        _monthlyData.map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
        ),
      );

      // 保存到本地持久化缓存
      await _storage.saveMonthlyData(_teamNo!, monthStr, _monthlyData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              forceAll
                  ? '全量更新完成，共更新 $updatedCount 天'
                  : updatedCount > 0
                  ? '智能更新完成，更新了 $updatedCount 天'
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
    await _smartQuickUpdate();
  }

  /// 智能快速更新
  /// 从今天开始往前遍历当月日期:
  /// - 无工时数据 → 更新这一天
  /// - 有工时但不一致 → 更新这一天
  /// - 有工时且一致 → 停止！信任该天及之前所有数据
  Future<int> _smartQuickUpdate() async {
    final now = DateTime.now();
    int updatedCount = 0;

    // 计算本月1号
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );

    // 从今天往前遍历到本月1号
    for (int i = 0; i <= now.difference(firstDayOfMonth).inDays; i++) {
      final targetDate = now.subtract(Duration(days: i));

      // 跳过不在当前选择月份的日期
      if (targetDate.year != _selectedMonth.year ||
          targetDate.month != _selectedMonth.month) {
        continue;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      // 跳过手动标记的日期
      if (_monthlyData[dateStr]?['isManual'] == true) {
        continue;
      }

      // 获取本地数据
      final localData = AttendanceData.fromLocal(_monthlyData[dateStr]);

      // 调用单日API获取数据
      final apiResponse = await _apiClient.getDailyAttendance(
        dateStr,
        _personNo!,
      );
      final apiData = AttendanceParser.parseFromResponse(apiResponse);

      final currentType = _monthlyData[dateStr]!['type'];

      // 检查是否需要类型修正 (使用统一工具类)
      final typeCorrection = SmartDayTypeHelper.inferDayType(
        currentType: currentType,
        hours: apiData.hours,
        dateStr: dateStr,
        isManual: false,
        hasCheckIn: apiData.hasValidData,
      );
      
      final needsTypeCorrection = typeCorrection != null && typeCorrection != currentType;

      // 比较是否一致 (只有当数据一致且不需要类型修正时，才停止更新)
      if (localData.hasValidData && localData.isConsistentWith(apiData) && !needsTypeCorrection) {
        // 一致！信任该天及之前的所有数据，停止更新
        break;
      } else {
        // 不一致或需要修正，更新这一天
        if (_monthlyData.containsKey(dateStr)) {
          _monthlyData[dateStr]!['hours'] = apiData.hours;
          _monthlyData[dateStr]!['apiHours'] = apiData.hours;
          _monthlyData[dateStr]!['checkIn'] = apiData.checkIn;
          _monthlyData[dateStr]!['checkOut'] = apiData.checkOut;
          _monthlyData[dateStr]!['isLate'] = apiData.isLate;
          _monthlyData[dateStr]!['isEarlyLeave'] = apiData.isEarlyLeave;

          // 应用类型修正
          if (needsTypeCorrection && typeCorrection != null) {
             _monthlyData[dateStr]!['type'] = typeCorrection;
          }

          updatedCount++;
        }
      }
    }

    return updatedCount;
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
                                if (!newAvailableMonths.contains(selectedMonth)) {
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
    _monthlyDataCache.clear();
    _apiClient.setToken('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月度统计'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
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
      elevation: 4,
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
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 操作按钮区域 - 使用 iPhone 8 Home 键风格的触感
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 第一行: 全量更新 + 快速更新（主要操作按钮）
        Row(
          children: [
            Expanded(
              child: HomeButtonIcon(
                onPressed: () => _updateAttendance(forceAll: true),
                icon: Icons.update,
                label: '全量更新工时',
                isOutlined: true,
                foregroundColor: AppColors.warningDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeButtonIcon(
                onPressed: () => _updateAttendance(forceAll: false),
                icon: Icons.refresh,
                label: '快速更新工时',
                backgroundColor: AppColors.success,
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
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Card(
      elevation: 2,
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
      elevation: 4,
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
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warningDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '如某天类型/工时有误，点击该日可手动修改',
                      style: TextStyle(fontSize: 12, color: AppColors.warningDark),
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
        bgColor = Colors.green;
        break;
      case '加班日':
        bgColor = Colors.purple;
        break;
      case '出差':
        bgColor = Colors.amber;
        break;
      case '请假':
        bgColor = Colors.red;
        break;
      case '自定义':
        bgColor = Colors.blue;
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
            ? Border.all(color: Colors.orange, width: 2)
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
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              if (hours > 0)
                Text(
                  '${WorkTimeCalculator.formatHours(hours)}H',
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
                                  color: Colors.green[600],
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
                                        ? Colors.green[700]
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
                                  color: Colors.orange[600],
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
                                        ? Colors.orange[700]
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
                                  color: Colors.blue[600],
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
                                Text(
                                  '${WorkTimeCalculator.formatHours(hours)}h',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                      children: AppConstants.allWorkTypes.map((
                        type,
                      ) {
                        final isSelected = currentType == type;

                        // 判断是否应该禁用此按钮
                        final isDisabled =
                            (type == AppConstants.typeOvertime || type == AppConstants.typeLeave) &&
                            dayData['type'] == AppConstants.typeRestDay &&
                            (dayData['hours'] == null ||
                                dayData['hours'] == 0.0);

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
                                      if ((type == AppConstants.typeBusinessTrip || type == AppConstants.typeCustom) &&
                                          (previousType == AppConstants.typeRestDay ||
                                              dayData['type'] == AppConstants.typeRestDay)) {
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
                    if (currentType == AppConstants.typeBusinessTrip || currentType == AppConstants.typeCustom) ...[
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
                       (currentType == AppConstants.typeBusinessTrip && isCustomHours)) ...[
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
                    icon: const Icon(Icons.restore, color: Colors.red),
                    label: const Text(
                      '恢复默认',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () async {
                      HapticUtils.mediumImpact(); // 恢复默认震动
                      await _restoreDefaultType(dateStr);
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
    final savedMarks = await _storage.loadCalendarMarks(_teamNo!);
    savedMarks[dateStr] = {
      'type': type,
      'isManual': true,
      'isOvertime': isOvertime,
      'isCustomHours': isCustomHours,
      if (type == AppConstants.typeCustom || (type == AppConstants.typeBusinessTrip && isCustomHours)) ...{
        'customCheckIn': customCheckIn,
        'customCheckOut': customCheckOut,
      },
    };
    await _storage.saveCalendarMarks(_teamNo!, savedMarks);

    // 只更新UI
    setState(() {
      if (_monthlyData.containsKey(dateStr)) {
        _monthlyData[dateStr]!['type'] = type;
        _monthlyData[dateStr]!['isManual'] = true;
        _monthlyData[dateStr]!['isOvertime'] = isOvertime;
        _monthlyData[dateStr]!['isCustomHours'] = isCustomHours;

        if (type == AppConstants.typeCustom) {
          _monthlyData[dateStr]!['customCheckIn'] = customCheckIn;
          _monthlyData[dateStr]!['customCheckOut'] = customCheckOut;
          // 计算自定义工时
          _monthlyData[dateStr]!['hours'] = _calculateCustomHours(
            customCheckIn,
            customCheckOut,
          );
        } else if (type == AppConstants.typeBusinessTrip) {
          if (isCustomHours) {
            _monthlyData[dateStr]!['customCheckIn'] = customCheckIn;
            _monthlyData[dateStr]!['customCheckOut'] = customCheckOut;
            _monthlyData[dateStr]!['hours'] = _calculateCustomHours(
              customCheckIn,
              customCheckOut,
            );
          } else {
            // 出差类型自动设定工时为8小时
            _monthlyData[dateStr]!['hours'] = 8.0;
          }
        } else if (type == AppConstants.typeLeave) {
          // 请假类型工时为0
          _monthlyData[dateStr]!['hours'] = 0.0;
        }
      }
    });
  }

  /// 计算自定义工时
  double _calculateCustomHours(String checkIn, String checkOut) {
    // 使用统一的工时计算工具类
    return WorkTimeCalculator.calculateWorkHoursStr(checkIn, checkOut);
  }

  /// 恢复默认类型（从节假日计划）
  Future<void> _restoreDefaultType(String dateStr) async {
    // 从default_plan恢复默认类型
    final defaultType =
        _holidayPlan[dateStr] ??
        (DateTime.parse(dateStr).weekday <= 5 ? AppConstants.typeWorkday : AppConstants.typeRestDay);

    // 删除手动标记
    final savedMarks = await _storage.loadCalendarMarks(_teamNo!);
    savedMarks.remove(dateStr);
    await _storage.saveCalendarMarks(_teamNo!, savedMarks);

    // 更新UI - 恢复默认类型和API工时
    setState(() {
      if (_monthlyData.containsKey(dateStr)) {
        final currentData = _monthlyData[dateStr]!;

        // 恢复默认时，始终从 API 原始工时恢复（如果API没有数据，恢复为0）
        // 这样无论之前是什么类型（自定义、出差、请假等），都能正确恢复
        final apiHours = currentData['apiHours'] ?? 0.0;
        currentData['hours'] = apiHours;

        currentData['type'] = defaultType;
        currentData['isManual'] = false;
        currentData.remove('isOvertime');
        currentData.remove('isCustomHours');
        currentData.remove('customCheckIn');
        currentData.remove('customCheckOut');
      }
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
    int workDayCount = 0, overtimeDayCount = 0, tripDayCount = 0;
    int leaveDayCount = 0, customDayCount = 0, restDayCount = 0;
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
      final hours = (data['hours'] ?? 0.0) as double;
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
          tripDayCount++;
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
          customDayCount++;
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
    final percentageWithToday = totalWorkDays > 0
        ? (totalHoursWithToday / (totalWorkDays * 8.0)) * 100
        : 0.0;

    // 计算排除今天的统计（只在当前月份有效）
    double totalHoursExcludingToday = totalHoursWithToday;
    int totalWorkDaysExcludingToday = totalWorkDays;
    if (isCurrentMonth) {
      final todayStr = DateHelper.formatDate(today);
      final todayData = _monthlyData[todayStr];
      if (todayData != null) {
        final todayType = todayData['type'] as String;
        final todayHours = (todayData['hours'] ?? 0.0) as double;
        final todayIsOvertime = (todayData['isOvertime'] ?? false) as bool;

        // 从总工时中减去今天的工时
        if (todayType == AppConstants.typeWorkday || todayType == AppConstants.typeLeave) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeOvertime) {
          totalHoursExcludingToday -= todayHours;
        } else if (todayType == AppConstants.typeCustom && !todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeCustom && todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
        } else if (todayType == AppConstants.typeBusinessTrip && !todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
          totalWorkDaysExcludingToday -= 1;
        } else if (todayType == AppConstants.typeBusinessTrip && todayIsOvertime) {
          totalHoursExcludingToday -= todayHours;
        }
      }
    }
    final percentageExcludingToday = totalWorkDaysExcludingToday > 0
        ? (totalHoursExcludingToday / (totalWorkDaysExcludingToday * 8.0)) * 100
        : 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 月度统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  Colors.green,
                ),
                _buildTypeChip(
                  AppConstants.typeOvertime,
                  overtimeDayCountAll,
                  overtimeDayHoursAll,
                  Colors.purple,
                ),
                _buildTypeChip(
                  AppConstants.typeBusinessTrip,
                  tripDayCountAll,
                  tripDayHoursAll,
                  Colors.amber,
                ),
                _buildTypeChip(
                  AppConstants.typeLeave,
                  leaveDayCountAll,
                  leaveDayHoursAll,
                  Colors.red,
                ),
                _buildTypeChip(
                  AppConstants.typeCustom,
                  customDayCountAll,
                  customDayHoursAll,
                  Colors.blue,
                ),
                _buildTypeChip('休息', restDayCountAll, 0.0, Colors.grey),
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
                  Colors.green,
                ),
                _buildStatColumn(
                  '总加班日',
                  '$totalOvertimeDays天/$totalOvertimeDaysAll天\n${WorkTimeCalculator.formatHours(totalOvertimeHours)}h',
                  Colors.purple,
                ),
                _buildStatColumn(
                  '总休息日',
                  '$totalRestDays天/$totalRestDaysAll天',
                  Colors.grey,
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
                  Colors.blue,
                ),
                _buildStatItem(
                  '日均工时',
                  WorkTimeCalculator.formatHours(avgHours),
                  '小时/天',
                  Colors.orange,
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
                child: Text(
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

    return Expanded(
      child: Card(
        color: percentage >= _baseTarget ? Colors.green[50] : Colors.orange[50],
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
              Text(
                '${WorkTimeCalculator.formatHours(percentage)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: percentage >= _baseTarget
                      ? Colors.green
                      : Colors.orange,
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
              Text(
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
            (type == AppConstants.typeCustom && !(todayData['isOvertime'] ?? false)) ||
            (type == AppConstants.typeBusinessTrip && !(todayData['isOvertime'] ?? false));

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
              (type == AppConstants.typeCustom && !(dayData['isOvertime'] ?? false)) ||
              (type == AppConstants.typeBusinessTrip && !(dayData['isOvertime'] ?? false));

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
    final currentPercentage = (adjustedTotalHours / baseHours) * 100;

    // 动态目标列表:如果160%已完成,扩展到300%
    List<int> targets = _generateTargetList(_baseTarget);
    if (currentPercentage >= 160) {
      targets.addAll([170, 180, 190, 200, 220, 240, 260, 280, 300]);
    }

    // 创建目标数据列表用于排序
    List<Map<String, dynamic>> targetData = targets.map((target) {
      final targetHours = (baseHours * target) / 100;
      final isCompleted = currentPercentage >= target;
      final gapHours = targetHours - adjustedTotalHours;
      final dailyNeed = remainingWorkDays > 0
          ? gapHours / remainingWorkDays
          : 0.0;

      final targetAvgHours = (8 * target) / 100;
      final avgProgress = avgHoursPerDay / targetAvgHours;
      final avgCompleted = avgProgress >= 1.0;

      return {
        'target': target,
        'targetHours': targetHours,
        'isCompleted': isCompleted,
        'avgCompleted': avgCompleted,
        'gapHours': gapHours,
        'dailyNeed': dailyNeed,
        'avgHoursPerDay': avgHoursPerDay,
        'targetAvgHours': targetAvgHours,
        'avgProgress': avgProgress,
      };
    }).toList();

    // 排序逻辑
    List<Map<String, dynamic>> sortedTargetData;
    int? highestAchievedTarget; // 最高达成
    int? nextToAchieveTarget; // 即将达成

    if (_smartSort) {
      // 智能排序逻辑:
      // 1. 第一位：日均已完成的最高目标（只有1个，如110%）→ 最高达成
      // 2. 第二位：日均未完成的第一个目标（只有1个，如120%）→ 即将达成
      // 3. 剩余：其他所有目标按target升序
      // 4. 最后：日均+总进度都完成的（折叠）

      // 分组
      List<Map<String, dynamic>> bothCompleted = []; // 日均+总进度都完成(折叠)
      List<Map<String, dynamic>> highestAchieved = []; // 日均已完成的最高目标(只有1个)
      List<Map<String, dynamic>> nextToAchieve = []; // 日均未完成的第一个(只有1个)
      List<Map<String, dynamic>> others = []; // 其他所有目标

      for (var data in targetData) {
        final avgCompleted = data['avgCompleted'] as bool;
        final isCompleted = data['isCompleted'] as bool;

        if (avgCompleted && isCompleted) {
          bothCompleted.add(data);
        } else {
          others.add(data);
        }
      }

      // 对others按target排序
      others.sort((a, b) => a['target'].compareTo(b['target']));

      // 从others中找出最高达成和即将达成
      Map<String, dynamic>? highestAchievedData;
      Map<String, dynamic>? nextToAchieveData;

      // 找出日均已完成的最高目标
      for (int i = others.length - 1; i >= 0; i--) {
        if (others[i]['avgCompleted'] as bool) {
          highestAchievedData = others[i];
          break;
        }
      }

      // 找出日均未完成的第一个目标
      for (var data in others) {
        if (!(data['avgCompleted'] as bool)) {
          nextToAchieveData = data;
          break;
        }
      }

      // 从others中移除这两个特殊目标
      if (highestAchievedData != null) {
        highestAchieved.add(highestAchievedData);
        others.remove(highestAchievedData);
        highestAchievedTarget = highestAchievedData['target'] as int;
      }
      if (nextToAchieveData != null) {
        nextToAchieve.add(nextToAchieveData);
        others.remove(nextToAchieveData);
        nextToAchieveTarget = nextToAchieveData['target'] as int;
      }

      // bothCompleted排序
      bothCompleted.sort((a, b) => a['target'].compareTo(b['target']));

      // 合并结果: 最高达成(1个) + 即将达成(1个) + 其他(升序) + 都完成(折叠)
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

      // 仍然需要找出最高达成和即将达成用于特殊标记显示
      for (int i = sortedTargetData.length - 1; i >= 0; i--) {
        if (sortedTargetData[i]['avgCompleted'] as bool) {
          highestAchievedTarget = sortedTargetData[i]['target'] as int;
          break;
        }
      }
      for (var data in sortedTargetData) {
        if (!(data['avgCompleted'] as bool)) {
          nextToAchieveTarget = data['target'] as int;
          break;
        }
      }
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
    final progress = currentHours / targetHours;
    final progressPercentage = (progress * 100).clamp(0.0, 100.0);
    final avgProgressPercentage = (avgProgress * 100).clamp(0.0, 100.0);

    Color getProgressColor() {
      if (isCompleted) return Colors.green;
      if (isBaseTarget) return Colors.orange;
      return Colors.blue;
    }

    Color getAvgProgressColor() {
      if (avgProgress >= 1.0) return Colors.green;
      if (isBaseTarget) return Colors.orange;
      return Colors.purple;
    }

    // 特殊标记的边框颜色
    Color? getBorderColor() {
      if (isHighestAchieved) return Colors.green; // 绿色 - 最高达成
      if (isNextToAchieve) return Colors.blue[700]; // 深蓝 - 即将达成
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
                  // 置顶标签优先显示
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
                      Text(
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
                      Text(
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
                Text(
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
      child: Text(
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
        Text(
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
            Text(
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
