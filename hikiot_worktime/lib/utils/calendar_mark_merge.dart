import '../core/constants/constants.dart';
import 'work_time_calculator.dart';

class CalendarMarkMerge {
  CalendarMarkMerge._();

  static Map<String, dynamic> applyMark(
    Map<String, dynamic> dayData,
    Map<String, dynamic> markData,
  ) {
    final result = Map<String, dynamic>.from(dayData);
    final type = markData['type'] as String? ?? result['type'] as String?;
    final isManual = markData.containsKey('isManual')
        ? markData['isManual'] == true
        : true;

    // 自动请假只是根据当时的空打卡事实推断出来的缓存结论。
    // 后续 API 如果已经确认有工时或打卡，必须以最新 API 事实为准。
    if (!isManual &&
        type == AppConstants.typeLeave &&
        _hasWorkEvidence(result)) {
      result['isManual'] = false;
      return result;
    }

    result['type'] = type;
    result['isManual'] = isManual;

    if (markData.containsKey('isOvertime')) {
      result['isOvertime'] = markData['isOvertime'];
    }
    if (markData.containsKey('targets')) {
      result['targets'] = markData['targets'];
    }

    if (type == AppConstants.typeCustom) {
      _applyCustomHours(result, markData);
    } else if (type == AppConstants.typeBusinessTrip) {
      _applyBusinessTripHours(result, markData);
    } else if (type == AppConstants.typeLeave) {
      result['hours'] = 0.0;
    } else if (markData.containsKey('hours')) {
      result['hours'] = (markData['hours'] as num?)?.toDouble() ?? 0.0;
    }

    return result;
  }

  static Map<String, dynamic> restoreDefault(
    Map<String, dynamic> currentData,
    String defaultType, {
    Map<String, dynamic>? attendanceData,
  }) {
    final result = Map<String, dynamic>.from(currentData);
    result['type'] = defaultType;
    result['isManual'] = false;

    final liveHours = (attendanceData?['hours'] as num?)?.toDouble();
    final apiHours = (result['apiHours'] as num?)?.toDouble();
    result['hours'] = liveHours ?? apiHours ?? 0.0;

    final checkIn = attendanceData?['checkInTime'] ?? result['checkIn'];
    final checkOut = attendanceData?['checkOutTime'] ?? result['checkOut'];
    if (checkIn != null) result['checkIn'] = checkIn;
    if (checkOut != null) result['checkOut'] = checkOut;

    result.remove('isOvertime');
    result.remove('isCustomHours');
    result.remove('customCheckIn');
    result.remove('customCheckOut');

    return result;
  }

  static void _applyCustomHours(
    Map<String, dynamic> result,
    Map<String, dynamic> markData,
  ) {
    final checkIn = markData['customCheckIn'] as String? ?? '09:00';
    final checkOut = markData['customCheckOut'] as String? ?? '18:00';
    result['customCheckIn'] = checkIn;
    result['customCheckOut'] = checkOut;
    result['hours'] = WorkTimeCalculator.calculateWorkHoursStr(
      checkIn,
      checkOut,
    );
  }

  static void _applyBusinessTripHours(
    Map<String, dynamic> result,
    Map<String, dynamic> markData,
  ) {
    final isCustomHours = markData['isCustomHours'] == true;
    result['isCustomHours'] = isCustomHours;

    if (isCustomHours) {
      _applyCustomHours(result, markData);
    } else {
      result['hours'] = AppConstants.businessTripHours;
    }
  }

  static bool _hasWorkEvidence(Map<String, dynamic> dayData) {
    final hours = (dayData['apiHours'] as num?) ?? (dayData['hours'] as num?);
    if (hours != null && hours > 0) return true;

    final checkIn = dayData['checkIn'] as String?;
    final checkOut = dayData['checkOut'] as String?;
    return _hasPunch(checkIn) || _hasPunch(checkOut);
  }

  static bool _hasPunch(String? value) {
    return value != null && value.isNotEmpty && value != '-';
  }
}
