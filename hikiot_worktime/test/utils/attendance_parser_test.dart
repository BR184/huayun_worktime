import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/attendance_parser.dart';
import 'package:hikiot_worktime/utils/date_helper.dart';
import 'package:hikiot_worktime/utils/work_time_calculator.dart';

void main() {
  group('AttendanceParser', () {
    setUp(() {
      DateHelper.crossDayMinutes = 4 * 60;
      WorkTimeCalculator.lunchStartMinutes = 12 * 60;
      WorkTimeCalculator.lunchEndMinutes = 13 * 60;
    });

    test('uses all shift details for first check-in and last check-out', () {
      final attendance = AttendanceParser.parse({
        'shiftId': 1,
        'shiftName': '工作日',
        'shiftDetails': [
          {
            'clockInTime': '09:00',
            'clockOffTime': '-',
            'clockInStatusType': 1,
            'clockOffStatusType': 0,
            'remoteClockInInfo': {'photo': 'in-first.jpg'},
          },
          {
            'clockInTime': '14:00',
            'clockOffTime': '19:30',
            'clockInStatusType': 0,
            'clockOffStatusType': 4,
            'remoteClockOffInfo': {'photo': 'out-last.jpg'},
          },
        ],
      });

      expect(attendance.checkIn, '09:00');
      expect(attendance.checkOut, '19:30');
      expect(attendance.hours, 9.5);
      expect(attendance.isLate, isTrue);
      expect(attendance.isEarlyLeave, isTrue);
      expect(attendance.checkInPhotoUrl, 'in-first.jpg');
      expect(attendance.checkOutPhotoUrl, 'out-last.jpg');
    });

    test('treats after-midnight check-out as later than same-day punches', () {
      final attendance = AttendanceParser.parse({
        'shiftId': 1,
        'shiftName': '夜班',
        'shiftDetails': [
          {
            'clockInTime': '21:00',
            'clockOffTime': '23:30',
            'remoteClockInInfo': {'photo': 'night-in.jpg'},
            'remoteClockOffInfo': {'photo': 'before-midnight.jpg'},
          },
          {
            'clockInTime': '-',
            'clockOffTime': '00:30',
            'remoteClockOffInfo': {'photo': 'after-midnight.jpg'},
          },
        ],
      });

      expect(attendance.checkIn, '21:00');
      expect(attendance.checkOut, '00:30');
      expect(attendance.hours, 3.5);
      expect(attendance.checkInPhotoUrl, 'night-in.jpg');
      expect(attendance.checkOutPhotoUrl, 'after-midnight.jpg');
    });

    test('marks after-midnight punches as cross-day reminder candidates', () {
      final attendance = AttendanceParser.parse({
        'shiftId': 1,
        'shiftName': 'night shift',
        'shiftDetails': [
          {'clockInTime': '09:00', 'clockOffTime': '00:30'},
        ],
      });

      expect(attendance.hasCrossDayPunch, isTrue);
      expect(attendance.crossDayPunchTime, '00:30');
    });
  });
}
