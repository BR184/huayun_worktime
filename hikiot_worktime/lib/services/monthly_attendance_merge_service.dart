import 'package:intl/intl.dart';

import '../core/constants/constants.dart';
import '../utils/calendar_mark_merge.dart';
import '../utils/holiday_utils.dart';
import '../utils/smart_day_type_helper.dart';

class MonthlyAttendanceMergeResult {
  const MonthlyAttendanceMergeResult({
    required this.monthlyData,
    required this.holidayPlan,
    required this.holidayPlanChanged,
    this.personName,
  });

  final Map<String, Map<String, dynamic>> monthlyData;
  final Map<String, String> holidayPlan;
  final bool holidayPlanChanged;
  final String? personName;
}

class MonthlyAttendanceMergeService {
  MonthlyAttendanceMergeResult merge({
    required DateTime selectedMonth,
    required Map<String, String> holidayPlan,
    required Map<String, dynamic> monthlyStats,
    required Map<String, Map<String, dynamic>> savedMarks,
  }) {
    final mutableHolidayPlan = Map<String, String>.from(holidayPlan);
    final dataMap = _buildDefaultMonthData(selectedMonth, mutableHolidayPlan);
    final dailyRecords = monthlyStats['dailyRecords'] as List<dynamic>? ?? [];
    var holidayPlanChanged = false;

    for (final rawRecord in dailyRecords) {
      if (rawRecord is! Map) continue;
      final record = Map<String, dynamic>.from(rawRecord);
      final date = record['date'] as String?;
      if (date == null || !dataMap.containsKey(date)) continue;

      final hours = (record['hours'] as num?)?.toDouble() ?? 0.0;
      final isRestDay = record['isRestDay'] == true;

      final newNativeType = HolidayUtils.determineNativeType(
        isRestDay: isRestDay,
        currentType: dataMap[date]!['type'] as String? ?? '',
        isManual: dataMap[date]!['isManual'] == true,
      );

      if (newNativeType != null) {
        dataMap[date]!['type'] = newNativeType;
        mutableHolidayPlan[date] = newNativeType;
        holidayPlanChanged = true;
      }

      dataMap[date] = {
        ...dataMap[date]!,
        'hours': hours,
        'apiHours': hours,
        'checkIn': record['checkIn'],
        'checkOut': record['checkOut'],
        'isLate': record['isLate'] ?? false,
        'isEarlyLeave': record['isEarlyLeave'] ?? false,
        'hasCrossDayPunch': record['hasCrossDayPunch'] == true,
        'crossDayPunchTime': record['crossDayPunchTime'],
        SmartDayTypeHelper.dataSourceStatusKey:
            record[SmartDayTypeHelper.dataSourceStatusKey] ??
            SmartDayTypeHelper.dataSourceStatusApiConfirmed,
      };

      final checkIn = record['checkIn'] as String?;
      final newType = SmartDayTypeHelper.inferDayType(
        currentType: dataMap[date]!['type'] as String?,
        hours: hours,
        dateStr: date,
        isManual: dataMap[date]!['isManual'] == true,
        hasCheckIn: checkIn != null && checkIn.isNotEmpty && checkIn != '-',
        dataSourceStatus: SmartDayTypeHelper.parseDataSourceStatus(
          dataMap[date]![SmartDayTypeHelper.dataSourceStatusKey],
        ),
      );

      if (newType != null) {
        dataMap[date]!['type'] = newType;
      }
    }

    savedMarks.forEach((date, mark) {
      if (dataMap.containsKey(date)) {
        dataMap[date] = CalendarMarkMerge.applyMark(dataMap[date]!, mark);
      }
    });

    final personName = monthlyStats['personName'];
    return MonthlyAttendanceMergeResult(
      monthlyData: dataMap,
      holidayPlan: mutableHolidayPlan,
      holidayPlanChanged: holidayPlanChanged,
      personName: personName is String && personName.isNotEmpty
          ? personName
          : null,
    );
  }

  Map<String, Map<String, dynamic>> _buildDefaultMonthData(
    DateTime selectedMonth,
    Map<String, String> holidayPlan,
  ) {
    final dataMap = <String, Map<String, dynamic>>{};
    final daysInMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedMonth.year, selectedMonth.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final defaultType =
          holidayPlan[dateStr] ??
          (date.weekday <= 5
              ? AppConstants.typeWorkday
              : AppConstants.typeRestDay);

      dataMap[dateStr] = {
        'hours': 0.0,
        'checkIn': null,
        'checkOut': null,
        'isLate': false,
        'isEarlyLeave': false,
        'hasCrossDayPunch': false,
        'crossDayPunchTime': null,
        'type': defaultType,
        'isManual': false,
        SmartDayTypeHelper.dataSourceStatusKey:
            SmartDayTypeHelper.dataSourceStatusUnknown,
      };
    }

    return dataMap;
  }
}
