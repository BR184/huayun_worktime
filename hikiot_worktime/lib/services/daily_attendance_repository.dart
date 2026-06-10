import '../core/constants/constants.dart';
import '../utils/attendance_parser.dart';
import '../utils/calendar_mark_merge.dart';
import '../utils/date_helper.dart';
import '../utils/holiday_utils.dart';
import '../utils/smart_day_type_helper.dart';
import 'hikiot_api_client.dart';
import 'storage_service.dart';

typedef DailyAttendanceApiLoader =
    Future<Map<String, dynamic>?> Function(
      String token,
      String date,
      String personNo,
    );

enum DailyAttendanceLoadStatus {
  loaded,
  missingTeam,
  missingToken,
  missingPersonNo,
}

class DailyAttendanceLoadResult {
  const DailyAttendanceLoadResult({
    required this.status,
    required this.teamNo,
    required this.holidayPlan,
    required this.dayData,
    required this.smartSort,
    required this.pinnedTarget,
    required this.baseTarget,
    this.attendanceData,
  });

  final DailyAttendanceLoadStatus status;
  final String? teamNo;
  final Map<String, String> holidayPlan;
  final Map<String, dynamic> dayData;
  final Map<String, dynamic>? attendanceData;
  final bool smartSort;
  final int? pinnedTarget;
  final int baseTarget;
}

class DailyMarkMutationResult {
  const DailyMarkMutationResult({
    required this.teamNo,
    required this.dateStr,
    required this.dayData,
  });

  final String teamNo;
  final String dateStr;
  final Map<String, dynamic> dayData;
}

class DailyAttendanceRepository {
  DailyAttendanceRepository({
    StorageService? storage,
    DailyAttendanceApiLoader? loadDailyAttendance,
  }) : _storage = storage ?? StorageService(),
       _loadDailyAttendance = loadDailyAttendance ?? _defaultLoadDaily;

  final StorageService _storage;
  final DailyAttendanceApiLoader _loadDailyAttendance;

  Future<DailyAttendanceLoadResult> load(
    DateTime selectedDate, {
    DateTime? workDate,
  }) async {
    final smartSort = await _storage.loadSmartSort();
    final pinnedTarget = await _storage.loadPinnedTarget();
    final baseTarget = await _storage.loadBaseTarget();
    final teamNo = await _storage.loadTeamNo();
    final dateKey = DateHelper.formatDate(selectedDate);

    if (teamNo == null) {
      return _result(
        status: DailyAttendanceLoadStatus.missingTeam,
        selectedDate: selectedDate,
        dateKey: dateKey,
        teamNo: null,
        holidayPlan: const {},
        dayData: const {},
        smartSort: smartSort,
        pinnedTarget: pinnedTarget,
        baseTarget: baseTarget,
      );
    }

    final holidayPlan = await _loadHolidayPlan(selectedDate);
    var dayData = await _buildDefaultDayData(
      selectedDate: selectedDate,
      dateKey: dateKey,
      teamNo: teamNo,
      holidayPlan: holidayPlan,
    );

    final effectiveWorkDate = workDate ?? DateHelper.getWorkDate();
    if (selectedDate.isAfter(effectiveWorkDate)) {
      return _result(
        status: DailyAttendanceLoadStatus.loaded,
        selectedDate: selectedDate,
        dateKey: dateKey,
        teamNo: teamNo,
        holidayPlan: holidayPlan,
        dayData: dayData,
        smartSort: smartSort,
        pinnedTarget: pinnedTarget,
        baseTarget: baseTarget,
      );
    }

    final token = await _storage.loadToken();
    if (token == null || token.isEmpty) {
      return _result(
        status: DailyAttendanceLoadStatus.missingToken,
        selectedDate: selectedDate,
        dateKey: dateKey,
        teamNo: teamNo,
        holidayPlan: holidayPlan,
        dayData: dayData,
        smartSort: smartSort,
        pinnedTarget: pinnedTarget,
        baseTarget: baseTarget,
      );
    }

    final personNo = await _storage.loadPersonNo();
    if (personNo == null || personNo.isEmpty) {
      return _result(
        status: DailyAttendanceLoadStatus.missingPersonNo,
        selectedDate: selectedDate,
        dateKey: dateKey,
        teamNo: teamNo,
        holidayPlan: holidayPlan,
        dayData: dayData,
        smartSort: smartSort,
        pinnedTarget: pinnedTarget,
        baseTarget: baseTarget,
      );
    }

    final response = await _loadDailyAttendance(token, dateKey, personNo);
    if (response == null) {
      return _result(
        status: DailyAttendanceLoadStatus.loaded,
        selectedDate: selectedDate,
        dateKey: dateKey,
        teamNo: teamNo,
        holidayPlan: holidayPlan,
        dayData: dayData,
        smartSort: smartSort,
        pinnedTarget: pinnedTarget,
        baseTarget: baseTarget,
      );
    }

    final attendance = AttendanceParser.parseFromResponse(response);
    final attendanceData = _toAttendanceData(attendance);
    dayData = await _applyAttendance(
      selectedDate: selectedDate,
      dateKey: dateKey,
      teamNo: teamNo,
      holidayPlan: holidayPlan,
      dayData: dayData,
      attendance: attendance,
    );

    return _result(
      status: DailyAttendanceLoadStatus.loaded,
      selectedDate: selectedDate,
      dateKey: dateKey,
      teamNo: teamNo,
      holidayPlan: holidayPlan,
      dayData: dayData,
      attendanceData: attendanceData,
      smartSort: smartSort,
      pinnedTarget: pinnedTarget,
      baseTarget: baseTarget,
    );
  }

  Future<DailyMarkMutationResult?> saveManualMark({
    required DateTime selectedDate,
    required Map<String, dynamic> markData,
    String? teamNo,
  }) async {
    final resolvedTeamNo = teamNo ?? await _storage.loadTeamNo();
    if (resolvedTeamNo == null) return null;

    final dateStr = DateHelper.formatDate(selectedDate);
    await _storage.saveSingleCalendarMark(resolvedTeamNo, dateStr, markData);

    return DailyMarkMutationResult(
      teamNo: resolvedTeamNo,
      dateStr: dateStr,
      dayData: CalendarMarkMerge.applyMark(const {}, markData),
    );
  }

  Future<DailyMarkMutationResult?> restoreDefaultMark({
    required DateTime selectedDate,
    required Map<String, dynamic> currentData,
    required Map<String, String> holidayPlan,
    Map<String, dynamic>? attendanceData,
    String? teamNo,
  }) async {
    final resolvedTeamNo = teamNo ?? await _storage.loadTeamNo();
    if (resolvedTeamNo == null) return null;

    final dateStr = DateHelper.formatDate(selectedDate);
    final marks = await _storage.loadCalendarMarks(resolvedTeamNo);
    marks.remove(dateStr);
    await _storage.saveCalendarMarks(resolvedTeamNo, marks);

    final defaultType =
        holidayPlan[dateStr] ??
        (selectedDate.weekday <= 5
            ? AppConstants.typeWorkday
            : AppConstants.typeRestDay);

    return DailyMarkMutationResult(
      teamNo: resolvedTeamNo,
      dateStr: dateStr,
      dayData: CalendarMarkMerge.restoreDefault(
        currentData,
        defaultType,
        attendanceData: attendanceData,
      ),
    );
  }

  Future<Map<String, dynamic>> _buildDefaultDayData({
    required DateTime selectedDate,
    required String dateKey,
    required String teamNo,
    required Map<String, String> holidayPlan,
  }) async {
    final defaultType =
        holidayPlan[dateKey] ??
        (selectedDate.weekday <= 5
            ? AppConstants.typeWorkday
            : AppConstants.typeRestDay);
    var dayData = <String, dynamic>{
      'type': defaultType,
      'isManual': false,
      'hours': 0.0,
      SmartDayTypeHelper.dataSourceStatusKey:
          SmartDayTypeHelper.dataSourceStatusUnknown,
    };

    final savedMarks = await _storage.loadCalendarMarks(teamNo);
    final savedMark = savedMarks[dateKey];
    if (savedMark != null) {
      dayData = CalendarMarkMerge.applyMark(dayData, savedMark);
    }

    return dayData;
  }

  Future<Map<String, dynamic>> _applyAttendance({
    required DateTime selectedDate,
    required String dateKey,
    required String teamNo,
    required Map<String, String> holidayPlan,
    required Map<String, dynamic> dayData,
    required AttendanceData attendance,
  }) async {
    final result = Map<String, dynamic>.from(dayData);
    final newNativeType = HolidayUtils.determineNativeType(
      isRestDay: attendance.isRestDay,
      currentType: result['type'] as String? ?? '',
      isManual: result['isManual'] == true,
    );

    if (newNativeType != null) {
      result['type'] = newNativeType;
      await HolidayUtils.saveHolidayUpdate(
        year: selectedDate.year,
        dateKey: dateKey,
        newType: newNativeType,
        holidayPlan: holidayPlan,
        storage: _storage,
      );
    }

    result['hasCrossDayPunch'] = attendance.hasCrossDayPunch;
    result['crossDayPunchTime'] = attendance.crossDayPunchTime;

    if (result['isManual'] == true) {
      return result;
    }

    result[SmartDayTypeHelper.dataSourceStatusKey] =
        SmartDayTypeHelper.dataSourceStatusApiConfirmed;

    final newType = SmartDayTypeHelper.inferDayType(
      currentType: result['type'] as String?,
      hours: attendance.hours,
      dateStr: dateKey,
      isManual: false,
      hasCheckIn: attendance.hasValidData,
      dataSourceStatus: DayDataSourceStatus.apiConfirmed,
    );

    var changed = false;
    if (newType != null) {
      result['type'] = newType;
      result['hours'] = newType == AppConstants.typeLeave
          ? 0.0
          : attendance.hours;
      changed = true;
    } else {
      result['hours'] = attendance.hours;
    }

    if (changed) {
      await _storage.saveSingleCalendarMark(teamNo, dateKey, {
        'type': result['type'],
        'hours': result['hours'],
        'isManual': false,
        'isOvertime': result['type'] == AppConstants.typeOvertime,
        SmartDayTypeHelper.dataSourceStatusKey:
            SmartDayTypeHelper.dataSourceStatusApiConfirmed,
      });
    }

    return result;
  }

  Future<Map<String, String>> _loadHolidayPlan(DateTime selectedDate) async {
    var holidayPlan = await _storage.getHolidayPlan(selectedDate.year);
    if (holidayPlan.isEmpty) {
      holidayPlan = _storage.generateDefaultPlan(
        selectedDate.year,
        selectedDate.month,
      );
    }
    return holidayPlan;
  }

  Map<String, dynamic> _toAttendanceData(AttendanceData attendance) {
    return {
      'checkInTime': attendance.checkIn,
      'checkOutTime': attendance.checkOut,
      'hours': attendance.hours,
      'checkInPhotoUrl': attendance.checkInPhotoUrl,
      'checkOutPhotoUrl': attendance.checkOutPhotoUrl,
      'hasCrossDayPunch': attendance.hasCrossDayPunch,
      'crossDayPunchTime': attendance.crossDayPunchTime,
      SmartDayTypeHelper.dataSourceStatusKey:
          SmartDayTypeHelper.dataSourceStatusApiConfirmed,
    };
  }

  DailyAttendanceLoadResult _result({
    required DailyAttendanceLoadStatus status,
    required DateTime selectedDate,
    required String dateKey,
    required String? teamNo,
    required Map<String, String> holidayPlan,
    required Map<String, dynamic> dayData,
    required bool smartSort,
    required int? pinnedTarget,
    required int baseTarget,
    Map<String, dynamic>? attendanceData,
  }) {
    return DailyAttendanceLoadResult(
      status: status,
      teamNo: teamNo,
      holidayPlan: Map<String, String>.from(holidayPlan),
      dayData: Map<String, dynamic>.from(dayData),
      attendanceData: attendanceData == null
          ? null
          : Map<String, dynamic>.from(attendanceData),
      smartSort: smartSort,
      pinnedTarget: pinnedTarget,
      baseTarget: baseTarget,
    );
  }

  static Future<Map<String, dynamic>?> _defaultLoadDaily(
    String token,
    String date,
    String personNo,
  ) {
    return HikiotApiClient(token: token).getDailyAttendance(date, personNo);
  }
}
