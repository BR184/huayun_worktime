import '../core/error/exceptions.dart';
import '../utils/attendance_parser.dart';
import '../utils/smart_day_type_helper.dart';

typedef MonthlyDailyLoader =
    Future<Map<String, dynamic>?> Function(String date, String personNo);

class MonthlyAttendanceAggregator {
  final String month;
  final String personNo;
  final int maxConcurrent;
  final MonthlyDailyLoader loadDailyAttendance;

  MonthlyAttendanceAggregator({
    required this.month,
    required this.personNo,
    required this.loadDailyAttendance,
    this.maxConcurrent = 6,
  });

  Future<Map<String, dynamic>> aggregate() async {
    final dates = _datesInMonth(month);
    final dailyRecords = <Map<String, dynamic>>[];
    final failedDates = <String>[];
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        if (index >= dates.length) return;
        nextIndex++;

        final date = dates[index];
        try {
          final dailyData = await loadDailyAttendance(date, personNo);
          if (dailyData == null) {
            failedDates.add(date);
            continue;
          }

          final record = _toDailyRecord(date, dailyData);
          if (record != null) {
            dailyRecords.add(record);
          } else {
            failedDates.add(date);
          }
        } on TokenExpiredException {
          rethrow;
        } catch (_) {
          failedDates.add(date);
        }
      }
    }

    final workerCount = maxConcurrent.clamp(1, dates.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    dailyRecords.sort((a, b) {
      final left = a['date'] as String;
      final right = b['date'] as String;
      return left.compareTo(right);
    });
    failedDates.sort();

    final recordsWithPunch = dailyRecords.where((record) {
      final checkIn = record['checkIn'] as String?;
      return checkIn != null && checkIn.isNotEmpty && checkIn != '-';
    }).toList();

    final totalHours = recordsWithPunch.fold<double>(
      0.0,
      (sum, record) => sum + ((record['hours'] as num?)?.toDouble() ?? 0.0),
    );
    final workDays = recordsWithPunch.length;
    final lateCount = recordsWithPunch
        .where((record) => record['isLate'] == true)
        .length;
    final personName = dailyRecords
        .map((record) => record['personName'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String?>()
        .firstOrNull;

    return {
      'workDays': workDays,
      'totalHours': totalHours,
      'avgHours': workDays > 0 ? totalHours / workDays : 0.0,
      'lateCount': lateCount,
      'dailyRecords': dailyRecords,
      'personName': personName,
      'failedDates': failedDates,
    };
  }

  static Map<String, dynamic>? _toDailyRecord(
    String date,
    Map<String, dynamic> dailyData,
  ) {
    final dailyDetail = dailyData['dailyDetail'] as Map<String, dynamic>?;
    if (dailyDetail == null) return null;

    final attendance = AttendanceParser.parse(dailyDetail);
    return {
      'date': date,
      'checkIn': attendance.checkIn,
      'checkOut': attendance.checkOut,
      'hours': attendance.hours,
      'isLate': attendance.isLate,
      'isEarlyLeave': attendance.isEarlyLeave,
      'isRestDay': attendance.isRestDay,
      'personName': dailyData['personName'] as String?,
      SmartDayTypeHelper.dataSourceStatusKey:
          SmartDayTypeHelper.dataSourceStatusApiConfirmed,
    };
  }

  static List<String> _datesInMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      throw const ValidationException('月份格式错误');
    }

    final year = int.parse(parts[0]);
    final monthNum = int.parse(parts[1]);
    final lastDay = DateTime(year, monthNum + 1, 0).day;

    return List.generate(lastDay, (index) {
      final day = index + 1;
      return '${year.toString().padLeft(4, '0')}-'
          '${monthNum.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    });
  }
}
