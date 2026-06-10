import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/services/monthly_attendance_aggregator.dart';

void main() {
  group('MonthlyAttendanceAggregator', () {
    test('aggregates daily records and totals for a month', () async {
      final aggregator = MonthlyAttendanceAggregator(
        month: '2026-02',
        personNo: 'person-1',
        loadDailyAttendance: (date, personNo) async {
          return _dailyResponse(date, late: date == '2026-02-02');
        },
      );

      final result = await aggregator.aggregate();

      expect(result['workDays'], 28);
      expect(result['totalHours'], 224.0);
      expect(result['avgHours'], 8.0);
      expect(result['lateCount'], 1);
      expect(result['personName'], '测试用户');
      expect(result['failedDates'], isEmpty);
      expect(result['dailyRecords'], hasLength(28));
    });

    test('limits concurrent daily requests', () async {
      var inFlight = 0;
      var maxObserved = 0;

      final aggregator = MonthlyAttendanceAggregator(
        month: '2026-02',
        personNo: 'person-1',
        maxConcurrent: 3,
        loadDailyAttendance: (date, personNo) async {
          inFlight++;
          if (inFlight > maxObserved) {
            maxObserved = inFlight;
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return _dailyResponse(date);
        },
      );

      await aggregator.aggregate();

      expect(maxObserved, greaterThan(1));
      expect(maxObserved, lessThanOrEqualTo(3));
    });

    test('keeps the month usable when individual days fail', () async {
      final aggregator = MonthlyAttendanceAggregator(
        month: '2026-02',
        personNo: 'person-1',
        loadDailyAttendance: (date, personNo) async {
          if (date == '2026-02-02') {
            throw Exception('network down');
          }
          if (date == '2026-02-03') {
            return null;
          }
          return _dailyResponse(date);
        },
      );

      final result = await aggregator.aggregate();

      expect(result['dailyRecords'], hasLength(26));
      expect(result['failedDates'], ['2026-02-02', '2026-02-03']);
      expect(result['workDays'], 26);
    });

    test('does not swallow token-expired failures', () async {
      final aggregator = MonthlyAttendanceAggregator(
        month: '2026-02',
        personNo: 'person-1',
        loadDailyAttendance: (date, personNo) async {
          throw const TokenExpiredException();
        },
      );

      expect(aggregator.aggregate(), throwsA(isA<TokenExpiredException>()));
    });

    test('carries cross-day reminder metadata from daily records', () async {
      final aggregator = MonthlyAttendanceAggregator(
        month: '2026-02',
        personNo: 'person-1',
        loadDailyAttendance: (date, personNo) async {
          return _dailyResponse(date, checkOut: '00:30');
        },
      );

      final result = await aggregator.aggregate();
      final records = result['dailyRecords'] as List<dynamic>;

      expect(records.first['hasCrossDayPunch'], isTrue);
      expect(records.first['crossDayPunchTime'], '00:30');
    });
  });
}

Map<String, dynamic> _dailyResponse(
  String date, {
  bool late = false,
  String checkOut = '18:00',
}) {
  return {
    'personName': '测试用户',
    'dailyDetail': {
      'shiftId': 1,
      'shiftName': '工作日',
      'shiftDetails': [
        {
          'clockInTime': '09:00',
          'clockOffTime': checkOut,
          'clockInStatusType': late ? 1 : 0,
          'clockOffStatusType': 0,
        },
      ],
    },
  };
}
