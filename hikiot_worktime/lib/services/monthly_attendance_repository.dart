import 'package:intl/intl.dart';

import '../core/constants/constants.dart';
import '../utils/attendance_parser.dart';
import '../utils/calendar_mark_merge.dart';
import '../utils/date_helper.dart';
import '../utils/smart_day_type_helper.dart';
import 'monthly_attendance_merge_service.dart';
import 'storage_service.dart';

typedef MonthlyAttendanceLoader =
    Future<Map<String, dynamic>?> Function(String month, String personNo);
typedef MonthlyDailyAttendanceLoader =
    Future<Map<String, dynamic>?> Function(String date, String personNo);

enum MonthlyAttendanceLoadSource { memoryCache, persistentCache, api }

class MonthlyAttendanceLoadResult {
  const MonthlyAttendanceLoadResult({
    required this.monthlyData,
    required this.holidayPlan,
    required this.source,
    this.personName,
  });

  final Map<String, Map<String, dynamic>> monthlyData;
  final Map<String, String> holidayPlan;
  final MonthlyAttendanceLoadSource source;
  final String? personName;
}

class MonthlyAttendanceUpdateResult {
  const MonthlyAttendanceUpdateResult({
    required this.monthlyData,
    required this.updatedCount,
    required this.holidayPlan,
  });

  final Map<String, Map<String, dynamic>> monthlyData;
  final int updatedCount;
  final Map<String, String> holidayPlan;
}

class MonthlyAttendanceBackgroundUpdateResult {
  const MonthlyAttendanceBackgroundUpdateResult({
    this.updateResult,
    this.error,
    this.stackTrace,
  });

  final MonthlyAttendanceUpdateResult? updateResult;
  final Object? error;
  final StackTrace? stackTrace;
}

class MonthlyAttendanceRepository {
  MonthlyAttendanceRepository({
    StorageService? storage,
    MonthlyAttendanceMergeService? mergeService,
    required MonthlyAttendanceLoader loadMonthlyAttendance,
    required MonthlyDailyAttendanceLoader loadDailyAttendance,
  }) : _storage = storage ?? StorageService(),
       _mergeService = mergeService ?? MonthlyAttendanceMergeService(),
       _loadMonthlyAttendance = loadMonthlyAttendance,
       _loadDailyAttendance = loadDailyAttendance;

  final StorageService _storage;
  final MonthlyAttendanceMergeService _mergeService;
  final MonthlyAttendanceLoader _loadMonthlyAttendance;
  final MonthlyDailyAttendanceLoader _loadDailyAttendance;
  final Map<String, Map<String, Map<String, dynamic>>> _memoryCache = {};

  void clearCache() => _memoryCache.clear();

  Future<MonthlyAttendanceLoadResult> loadMonth({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
    bool forceRefresh = false,
  }) async {
    final monthStr = _monthStr(selectedMonth);
    final cacheKey = _cacheKey(teamNo, selectedMonth);

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      return MonthlyAttendanceLoadResult(
        monthlyData: _copyMonth(_memoryCache[cacheKey]!),
        holidayPlan: await _loadHolidayPlan(selectedMonth),
        source: MonthlyAttendanceLoadSource.memoryCache,
      );
    }

    if (!forceRefresh) {
      final cachedData = await _storage.loadMonthlyData(teamNo, monthStr);
      if (cachedData != null) {
        SmartDayTypeHelper.applyToMonthlyData(cachedData);
        _memoryCache[cacheKey] = _copyMonth(cachedData);
        return MonthlyAttendanceLoadResult(
          monthlyData: _copyMonth(cachedData),
          holidayPlan: await _loadHolidayPlan(selectedMonth),
          source: MonthlyAttendanceLoadSource.persistentCache,
        );
      }
    }

    return _loadFromApi(
      teamNo: teamNo,
      personNo: personNo,
      selectedMonth: selectedMonth,
    );
  }

  Future<MonthlyAttendanceLoadResult> _loadFromApi({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
  }) async {
    final monthStr = _monthStr(selectedMonth);
    final holidayPlan = await _loadHolidayPlan(selectedMonth);
    final monthlyStats = await _loadMonthlyAttendance(monthStr, personNo);
    if (monthlyStats == null) {
      throw Exception('获取月度数据失败');
    }

    final savedMarks = await _storage.loadCalendarMarks(teamNo);
    final mergeResult = _mergeService.merge(
      selectedMonth: selectedMonth,
      holidayPlan: holidayPlan,
      monthlyStats: monthlyStats,
      savedMarks: savedMarks,
    );

    if (mergeResult.holidayPlanChanged) {
      await _storage.saveHolidayPlan(
        selectedMonth.year,
        mergeResult.holidayPlan,
      );
    }
    if (mergeResult.personName != null) {
      await _storage.saveUserName(mergeResult.personName!);
    }

    final monthData = _copyMonth(mergeResult.monthlyData);
    _memoryCache[_cacheKey(teamNo, selectedMonth)] = _copyMonth(monthData);
    await _storage.saveMonthlyData(teamNo, monthStr, monthData);

    return MonthlyAttendanceLoadResult(
      monthlyData: _copyMonth(monthData),
      holidayPlan: Map<String, String>.from(mergeResult.holidayPlan),
      source: MonthlyAttendanceLoadSource.api,
      personName: mergeResult.personName,
    );
  }

  Future<MonthlyAttendanceUpdateResult> forceRefreshMonth({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
  }) async {
    final result = await _loadFromApi(
      teamNo: teamNo,
      personNo: personNo,
      selectedMonth: selectedMonth,
    );
    final updatedCount = result.monthlyData.values
        .where(
          (data) =>
              data[SmartDayTypeHelper.dataSourceStatusKey] ==
              SmartDayTypeHelper.dataSourceStatusApiConfirmed,
        )
        .length;
    return MonthlyAttendanceUpdateResult(
      monthlyData: result.monthlyData,
      updatedCount: updatedCount,
      holidayPlan: result.holidayPlan,
    );
  }

  Future<MonthlyAttendanceUpdateResult> smartQuickUpdate({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    DateTime? now,
  }) async {
    final monthData = _copyMonth(currentData);
    final today = now ?? DateTime.now();
    var updatedCount = 0;
    final firstDayOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    for (var i = 0; i <= today.difference(firstDayOfMonth).inDays; i++) {
      final targetDate = today.subtract(Duration(days: i));
      if (targetDate.year != selectedMonth.year ||
          targetDate.month != selectedMonth.month) {
        continue;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final localRow = monthData[dateStr];
      if (localRow == null || localRow['isManual'] == true) {
        continue;
      }

      final localData = AttendanceData.fromLocal(localRow);
      final apiResponse = await _loadDailyAttendance(dateStr, personNo);
      final apiData = AttendanceParser.parseFromResponse(apiResponse);
      final currentType = localRow['type'] as String?;
      final typeCorrection = SmartDayTypeHelper.inferDayType(
        currentType: currentType,
        hours: apiData.hours,
        dateStr: dateStr,
        isManual: false,
        hasCheckIn: apiData.hasValidData,
        dataSourceStatus: DayDataSourceStatus.apiConfirmed,
      );
      final needsTypeCorrection =
          typeCorrection != null && typeCorrection != currentType;

      if (localData.hasValidData &&
          localData.isConsistentWith(apiData) &&
          !needsTypeCorrection) {
        break;
      }

      localRow['hours'] = apiData.hours;
      localRow['apiHours'] = apiData.hours;
      localRow['checkIn'] = apiData.checkIn;
      localRow['checkOut'] = apiData.checkOut;
      localRow['isLate'] = apiData.isLate;
      localRow['isEarlyLeave'] = apiData.isEarlyLeave;
      localRow[SmartDayTypeHelper.dataSourceStatusKey] =
          SmartDayTypeHelper.dataSourceStatusApiConfirmed;
      if (needsTypeCorrection) {
        localRow['type'] = typeCorrection;
      }
      updatedCount++;
    }

    await _persistMonth(teamNo, selectedMonth, monthData);
    return MonthlyAttendanceUpdateResult(
      monthlyData: _copyMonth(monthData),
      updatedCount: updatedCount,
      holidayPlan: await _loadHolidayPlan(selectedMonth),
    );
  }

  Future<MonthlyAttendanceBackgroundUpdateResult> smartQuickUpdateSafely({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    DateTime? now,
  }) async {
    try {
      return MonthlyAttendanceBackgroundUpdateResult(
        updateResult: await smartQuickUpdate(
          teamNo: teamNo,
          personNo: personNo,
          selectedMonth: selectedMonth,
          currentData: currentData,
          now: now,
        ),
      );
    } catch (error, stackTrace) {
      return MonthlyAttendanceBackgroundUpdateResult(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<MonthlyAttendanceUpdateResult> refreshToday({
    required String teamNo,
    required String personNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    DateTime? workDate,
  }) async {
    final targetDate = workDate ?? DateHelper.getWorkDate();
    if (selectedMonth.year != targetDate.year ||
        selectedMonth.month != targetDate.month) {
      return MonthlyAttendanceUpdateResult(
        monthlyData: _copyMonth(currentData),
        updatedCount: 0,
        holidayPlan: await _loadHolidayPlan(selectedMonth),
      );
    }

    final dateStr = DateHelper.formatDate(targetDate);
    final monthData = _copyMonth(currentData);
    final row = monthData[dateStr];
    if (row == null || row['isManual'] == true) {
      return MonthlyAttendanceUpdateResult(
        monthlyData: monthData,
        updatedCount: 0,
        holidayPlan: await _loadHolidayPlan(selectedMonth),
      );
    }

    final apiResponse = await _loadDailyAttendance(dateStr, personNo);
    final attendance = AttendanceParser.parseFromResponse(apiResponse);
    row['hours'] = attendance.hours;
    row['apiHours'] = attendance.hours;
    row['checkIn'] = attendance.checkIn;
    row['checkOut'] = attendance.checkOut;
    row[SmartDayTypeHelper.dataSourceStatusKey] =
        SmartDayTypeHelper.dataSourceStatusApiConfirmed;

    final newType = SmartDayTypeHelper.inferDayType(
      currentType: row['type'] as String?,
      hours: attendance.hours,
      dateStr: dateStr,
      isManual: false,
      hasCheckIn: attendance.hasValidData,
      dataSourceStatus: DayDataSourceStatus.apiConfirmed,
    );
    if (newType != null) {
      row['type'] = newType;
    }

    await _persistMonth(teamNo, selectedMonth, monthData);
    return MonthlyAttendanceUpdateResult(
      monthlyData: monthData,
      updatedCount: 1,
      holidayPlan: await _loadHolidayPlan(selectedMonth),
    );
  }

  Future<MonthlyAttendanceUpdateResult> refreshFromMarks({
    required String teamNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    required Map<String, String> holidayPlan,
  }) async {
    final savedMarks = await _storage.loadCalendarMarks(teamNo);
    final monthData = _copyMonth(currentData);

    savedMarks.forEach((dateStr, markData) {
      final row = monthData[dateStr];
      if (row != null) {
        monthData[dateStr] = CalendarMarkMerge.applyMark(row, markData);
      }
    });

    monthData.forEach((dateStr, data) {
      if (data['isManual'] == true && !savedMarks.containsKey(dateStr)) {
        final date = DateTime.parse(dateStr);
        final defaultType =
            holidayPlan[dateStr] ??
            (date.weekday <= 5
                ? AppConstants.typeWorkday
                : AppConstants.typeRestDay);
        monthData[dateStr] = CalendarMarkMerge.restoreDefault(
          data,
          defaultType,
        );
      }
    });

    await _persistMonth(teamNo, selectedMonth, monthData);
    return MonthlyAttendanceUpdateResult(
      monthlyData: monthData,
      updatedCount: 0,
      holidayPlan: Map<String, String>.from(holidayPlan),
    );
  }

  Future<MonthlyAttendanceUpdateResult> saveDaySettings({
    required String teamNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    required String dateStr,
    required String type,
    required bool isOvertime,
    required bool isCustomHours,
    required String customCheckIn,
    required String customCheckOut,
  }) async {
    final monthData = _copyMonth(currentData);
    final markData = <String, dynamic>{
      'type': type,
      'isManual': true,
      'isOvertime': isOvertime,
      'isCustomHours': isCustomHours,
      if (type == AppConstants.typeCustom ||
          (type == AppConstants.typeBusinessTrip && isCustomHours)) ...{
        'customCheckIn': customCheckIn,
        'customCheckOut': customCheckOut,
      },
    };

    await _storage.saveSingleCalendarMark(teamNo, dateStr, markData);
    final row = monthData[dateStr];
    if (row != null) {
      monthData[dateStr] = CalendarMarkMerge.applyMark(row, markData);
    }

    await _persistMonth(teamNo, selectedMonth, monthData);
    return MonthlyAttendanceUpdateResult(
      monthlyData: _copyMonth(monthData),
      updatedCount: 0,
      holidayPlan: await _loadHolidayPlan(selectedMonth),
    );
  }

  Future<MonthlyAttendanceUpdateResult> restoreDefaultType({
    required String teamNo,
    required DateTime selectedMonth,
    required Map<String, Map<String, dynamic>> currentData,
    required Map<String, String> holidayPlan,
    required String dateStr,
  }) async {
    final monthData = _copyMonth(currentData);
    final marks = await _storage.loadCalendarMarks(teamNo);
    marks.remove(dateStr);
    await _storage.saveCalendarMarks(teamNo, marks);

    final row = monthData[dateStr];
    if (row != null) {
      final date = DateTime.parse(dateStr);
      final defaultType =
          holidayPlan[dateStr] ??
          (date.weekday <= 5
              ? AppConstants.typeWorkday
              : AppConstants.typeRestDay);
      monthData[dateStr] = CalendarMarkMerge.restoreDefault(row, defaultType);
    }

    await _persistMonth(teamNo, selectedMonth, monthData);
    return MonthlyAttendanceUpdateResult(
      monthlyData: _copyMonth(monthData),
      updatedCount: 0,
      holidayPlan: Map<String, String>.from(holidayPlan),
    );
  }

  Future<void> _persistMonth(
    String teamNo,
    DateTime selectedMonth,
    Map<String, Map<String, dynamic>> monthData,
  ) async {
    final copy = _copyMonth(monthData);
    _memoryCache[_cacheKey(teamNo, selectedMonth)] = copy;
    await _storage.saveMonthlyData(teamNo, _monthStr(selectedMonth), copy);
  }

  Future<Map<String, String>> _loadHolidayPlan(DateTime selectedMonth) async {
    final yearPlan = await _storage.getHolidayPlan(selectedMonth.year);
    if (yearPlan.isNotEmpty) {
      return Map<String, String>.from(yearPlan);
    }
    return _storage.generateDefaultPlan(
      selectedMonth.year,
      selectedMonth.month,
    );
  }

  String _monthStr(DateTime selectedMonth) {
    return DateFormat('yyyy-MM').format(selectedMonth);
  }

  String _cacheKey(String teamNo, DateTime selectedMonth) {
    return '${teamNo}_${_monthStr(selectedMonth)}';
  }

  Map<String, Map<String, dynamic>> _copyMonth(
    Map<String, Map<String, dynamic>> data,
  ) {
    return data.map(
      (date, row) => MapEntry(date, Map<String, dynamic>.from(row)),
    );
  }
}
