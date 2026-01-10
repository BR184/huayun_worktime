import 'work_time_calculator.dart';

/// 考勤数据解析结果
class AttendanceData {
  final String? checkIn;
  final String? checkOut;
  final double hours;
  final bool isLate;
  final bool isEarlyLeave;

  const AttendanceData({
    this.checkIn,
    this.checkOut,
    this.hours = 0.0,
    this.isLate = false,
    this.isEarlyLeave = false,
  });

  /// 是否有有效的打卡数据
  bool get hasValidData =>
      checkIn != null &&
      checkOut != null &&
      checkIn!.isNotEmpty &&
      checkOut!.isNotEmpty &&
      checkIn != '-' &&
      checkOut != '-';

  /// 比较两个考勤数据是否一致（用于智能更新判断）
  bool isConsistentWith(AttendanceData other) {
    // 如果都没有数据，认为一致
    if (!hasValidData && !other.hasValidData) return true;
    // 如果一个有数据一个没有，不一致
    if (hasValidData != other.hasValidData) return false;
    // 比较上下班时间
    return checkIn == other.checkIn && checkOut == other.checkOut;
  }

  /// 从本地数据创建（用于比较）
  factory AttendanceData.fromLocal(Map<String, dynamic>? data) {
    if (data == null) return const AttendanceData();
    return AttendanceData(
      checkIn: data['checkIn'] as String?,
      checkOut: data['checkOut'] as String?,
      hours: (data['hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'AttendanceData(checkIn: $checkIn, checkOut: $checkOut, hours: $hours)';
}

/// 考勤数据解析工具
/// 统一处理工作日(shiftDetails)和加班日(restClockTime)的打卡数据解析
class AttendanceParser {
  /// 从 API 返回的 dailyDetail 解析考勤数据
  ///
  /// [dailyDetail] - API 返回的 dailyDetail 对象
  ///
  /// 解析规则:
  /// - 工作日: 从 shiftDetails[0] 取 clockInTime/clockOffTime
  /// - 加班日/休息日: 从 restClockTime 取第一个和最后一个打卡时间
  static AttendanceData parse(Map<String, dynamic>? dailyDetail) {
    if (dailyDetail == null) return const AttendanceData();

    final shiftDetails = dailyDetail['shiftDetails'] as List?;
    final restClockTime = dailyDetail['restClockTime'] as List?;

    String? clockIn;
    String? clockOut;
    bool isLate = false;
    bool isEarlyLeave = false;

    // 优先从 shiftDetails 取（正常工作日）
    if (shiftDetails != null && shiftDetails.isNotEmpty) {
      final firstShift = shiftDetails[0] as Map<String, dynamic>;
      clockIn = firstShift['clockInTime'] as String?;
      clockOut = firstShift['clockOffTime'] as String?;
      isLate = (firstShift['clockInStatusType'] as int? ?? 0) == 1;
      isEarlyLeave = (firstShift['clockOffStatusType'] as int? ?? 0) == 4;
    }
    // 如果没有 shiftDetails，从 restClockTime 取（加班日/休息日）
    else if (restClockTime != null && restClockTime.length >= 2) {
      final first = restClockTime.first as Map<String, dynamic>;
      final last = restClockTime.last as Map<String, dynamic>;
      clockIn = first['clockTime'] as String?;
      clockOut = last['clockTime'] as String?;
    }

    // 计算工时
    double hours = 0.0;
    if (clockIn != null &&
        clockOut != null &&
        clockIn.isNotEmpty &&
        clockOut.isNotEmpty &&
        clockIn != '-' &&
        clockOut != '-') {
      hours = WorkTimeCalculator.calculateWorkHoursStr(clockIn, clockOut);
    }

    return AttendanceData(
      checkIn: clockIn,
      checkOut: clockOut,
      hours: hours,
      isLate: isLate,
      isEarlyLeave: isEarlyLeave,
    );
  }

  /// 从完整的 API 响应解析（包含 dailyDetail 的响应）
  static AttendanceData parseFromResponse(Map<String, dynamic>? response) {
    if (response == null) return const AttendanceData();
    final dailyDetail = response['dailyDetail'] as Map<String, dynamic>?;
    return parse(dailyDetail);
  }
}
