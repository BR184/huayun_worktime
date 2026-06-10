import 'date_helper.dart';
import 'work_time_calculator.dart';

/// 考勤数据解析结果
class AttendanceData {
  final String? checkIn;
  final String? checkOut;
  final double hours;
  final bool isLate;
  final bool isEarlyLeave;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final bool isRestDay;
  final bool hasCrossDayPunch;
  final String? crossDayPunchTime;

  const AttendanceData({
    this.checkIn,
    this.checkOut,
    this.hours = 0.0,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
    this.isRestDay = false,
    this.hasCrossDayPunch = false,
    this.crossDayPunchTime,
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
      hasCrossDayPunch: data['hasCrossDayPunch'] == true,
      crossDayPunchTime: data['crossDayPunchTime'] as String?,
    );
  }

  @override
  String toString() =>
      'AttendanceData(checkIn: $checkIn, checkOut: $checkOut, hours: $hours)';
}

/// 考勤数据解析工具（支持 V2 API）
class AttendanceParser {
  /// 从 API 返回的 dailyDetail 解析考勤数据
  ///
  /// V2 API 返回 shiftDetails，包含 remoteClockInInfo.photo /
  /// remoteClockOffInfo.photo。凌晨打卡只标记为提醒，不自动归并到上一日。
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
    final punchTimes = <String?>[];

    // 海康原生休息日/节假日识别
    final shiftId = dailyDetail['shiftId'] as int? ?? 0;
    final shiftName = dailyDetail['shiftName'] as String? ?? '';
    final isRestDay = shiftId == -1 || shiftName.contains('休息');

    // 优先从 shiftDetails 取（V2 API 正常返回 shiftDetails）
    if (shiftDetails != null && shiftDetails.isNotEmpty) {
      final shifts = shiftDetails.whereType<Map<String, dynamic>>().toList();
      int? earliestClockInMinutes;

      for (final shift in shifts) {
        final shiftClockIn = shift['clockInTime'] as String?;
        final shiftClockOff = shift['clockOffTime'] as String?;
        punchTimes.addAll([shiftClockIn, shiftClockOff]);

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
    } else if (restClockTime != null && restClockTime.isNotEmpty) {
      // 回退：从 restClockTime 取（旧 API 兼容）
      final punches = restClockTime.whereType<Map<String, dynamic>>().toList();
      for (final punch in punches) {
        punchTimes.add(punch['clockTime'] as String?);
      }

      final first = punches.first;
      clockIn = first['clockTime'] as String?;
      if (punches.length >= 2) {
        final last = punches.last;
        clockOut = last['clockTime'] as String?;
      }
    }

    double hours = 0.0;
    if (clockIn != null &&
        clockOut != null &&
        clockIn.isNotEmpty &&
        clockOut.isNotEmpty &&
        clockIn != '-' &&
        clockOut != '-') {
      hours = WorkTimeCalculator.calculateWorkHoursStr(clockIn, clockOut);
    }

    final crossDayPunchTime = DateHelper.firstCrossDayReminderPunchTime(
      punchTimes,
    );

    return AttendanceData(
      checkIn: clockIn,
      checkOut: clockOut,
      hours: hours,
      isLate: isLate,
      isEarlyLeave: isEarlyLeave,
      checkInPhotoUrl: clockInPhoto,
      checkOutPhotoUrl: clockOutPhoto,
      isRestDay: isRestDay,
      hasCrossDayPunch: crossDayPunchTime != null,
      crossDayPunchTime: crossDayPunchTime,
    );
  }

  /// 从完整的 API 响应解析
  static AttendanceData parseFromResponse(Map<String, dynamic>? response) {
    if (response == null) return const AttendanceData();
    final dailyDetail = response['dailyDetail'] as Map<String, dynamic>?;
    return parse(dailyDetail);
  }
}
