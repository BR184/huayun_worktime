import 'work_time_calculator.dart';

/// 考勤数据解析结果
class AttendanceData {
  final String? checkIn;
  final String? checkOut;
  final double hours;
  final bool isLate;
  final bool isEarlyLeave;
  final String? checkInPhotoUrl; // 上班打卡照片
  final String? checkOutPhotoUrl; // 下班打卡照片
  final bool isRestDay; // 是否为休息日/节假日 (海康原生识别)

  const AttendanceData({
    this.checkIn,
    this.checkOut,
    this.hours = 0.0,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    this.isRestDay = false,
  });

  /// 是否有有效的打卡数据（至少有上班打卡）
  bool get hasValidData =>
      checkIn != null && checkIn!.isNotEmpty && checkIn != '-';

  /// 是否有完整的上下班打卡
  bool get hasFullPunch =>
      hasValidData &&
      checkOut != null &&
      checkOut!.isNotEmpty &&
      checkOut != '-';

  /// 比较两个考勤数据是否一致（用于智能更新判断）
  bool isConsistentWith(AttendanceData other) {
    if (!hasValidData && !other.hasValidData) return true;
    if (hasValidData != other.hasValidData) return false;
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

/// 考勤数据解析工具 (支持V2 API)
class AttendanceParser {
  /// 从 API 返回的 dailyDetail 解析考勤数据
  ///
  /// V2 API 返回 shiftDetails，包含 remoteClockInInfo.photo / remoteClockOffInfo.photo
  static AttendanceData parse(Map<String, dynamic>? dailyDetail) {
    if (dailyDetail == null) return const AttendanceData();

    final shiftDetails = dailyDetail['shiftDetails'] as List?;
    final restClockTime = dailyDetail['restClockTime'] as List?;

    String? clockIn;
    String? clockOut;
    String? clockInPhoto;
    String? clockOutPhoto;
    bool isLate = false;
    bool isEarlyLeave = false;

    // 海康原生休息日/节假日识别：
    // shiftId == -1 且 shiftName 包含 "休息"
    final shiftId = dailyDetail['shiftId'] as int? ?? 0;
    final shiftName = dailyDetail['shiftName'] as String? ?? '';
    final isRestDay = shiftId == -1 || shiftName.contains('休息');

    // 优先从 shiftDetails 取（V2 API 总是返回 shiftDetails）
    if (shiftDetails != null && shiftDetails.isNotEmpty) {
      final shifts = shiftDetails.whereType<Map<String, dynamic>>().toList();
      int? earliestClockInMinutes;

      for (final shift in shifts) {
        final shiftClockIn = shift['clockInTime'] as String?;
        final shiftClockInMinutes = WorkTimeCalculator.parseTimeToMinutes(
          shiftClockIn,
        );

        if (shiftClockInMinutes != null &&
            (earliestClockInMinutes == null ||
                shiftClockInMinutes < earliestClockInMinutes)) {
          earliestClockInMinutes = shiftClockInMinutes;
          clockIn = shiftClockIn;

          final remoteClockInInfo =
              shift['remoteClockInInfo'] as Map<String, dynamic>?;
          clockInPhoto = remoteClockInInfo?['photo'] as String?;
        }

        isLate = isLate || (shift['clockInStatusType'] as int? ?? 0) == 1;
        isEarlyLeave =
            isEarlyLeave || (shift['clockOffStatusType'] as int? ?? 0) == 4;
      }

      int? latestClockOutComparableMinutes;

      for (final shift in shifts) {
        final shiftClockOut = shift['clockOffTime'] as String?;
        final shiftClockOutMinutes = WorkTimeCalculator.parseTimeToMinutes(
          shiftClockOut,
        );
        if (shiftClockOutMinutes == null) continue;

        var comparableMinutes = shiftClockOutMinutes;
        if (earliestClockInMinutes != null &&
            comparableMinutes < earliestClockInMinutes) {
          comparableMinutes += 24 * 60;
        }

        if (latestClockOutComparableMinutes == null ||
            comparableMinutes > latestClockOutComparableMinutes) {
          latestClockOutComparableMinutes = comparableMinutes;
          clockOut = shiftClockOut;

          final remoteClockOffInfo =
              shift['remoteClockOffInfo'] as Map<String, dynamic>?;
          clockOutPhoto = remoteClockOffInfo?['photo'] as String?;
        }
      }
    }
    // 回退：从 restClockTime 取（旧API兼容）
    else if (restClockTime != null && restClockTime.isNotEmpty) {
      final first = restClockTime.first as Map<String, dynamic>;
      clockIn = first['clockTime'] as String?;
      // 多次打卡时取最后一次作为下班
      if (restClockTime.length >= 2) {
        final last = restClockTime.last as Map<String, dynamic>;
        clockOut = last['clockTime'] as String?;
      }
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
      checkInPhotoUrl: clockInPhoto,
      checkOutPhotoUrl: clockOutPhoto,
      isRestDay: isRestDay,
    );
  }

  /// 从完整的 API 响应解析
  static AttendanceData parseFromResponse(Map<String, dynamic>? response) {
    if (response == null) return const AttendanceData();
    final dailyDetail = response['dailyDetail'] as Map<String, dynamic>?;
    return parse(dailyDetail);
  }
}
