import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/utils/calendar_mark_merge.dart';

void main() {
  group('CalendarMarkMerge', () {
    test(
      'keeps an automatic leave mark when API still has no work evidence',
      () {
        final apiDay = <String, dynamic>{
          'type': AppConstants.typeWorkday,
          'hours': 0.0,
          'apiHours': 0.0,
          'checkIn': null,
          'checkOut': null,
          'isManual': false,
        };
        final autoMark = <String, dynamic>{
          'type': AppConstants.typeLeave,
          'hours': 0.0,
          'isManual': false,
        };

        final merged = CalendarMarkMerge.applyMark(apiDay, autoMark);

        expect(merged['type'], AppConstants.typeLeave);
        expect(merged['hours'], 0.0);
        expect(merged['isManual'], isFalse);
      },
    );

    test('ignores stale automatic leave mark when API has work hours', () {
      final apiDay = <String, dynamic>{
        'type': AppConstants.typeWorkday,
        'hours': 8.5,
        'apiHours': 8.5,
        'checkIn': '09:00',
        'checkOut': '18:30',
        'isManual': false,
      };
      final staleAutoLeaveMark = <String, dynamic>{
        'type': AppConstants.typeLeave,
        'hours': 0.0,
        'isManual': false,
      };

      final merged = CalendarMarkMerge.applyMark(apiDay, staleAutoLeaveMark);

      expect(merged['type'], AppConstants.typeWorkday);
      expect(merged['hours'], 8.5);
      expect(merged['isManual'], isFalse);
    });

    test('keeps manual leave mark even when API has work hours', () {
      final apiDay = <String, dynamic>{
        'type': AppConstants.typeWorkday,
        'hours': 8.5,
        'apiHours': 8.5,
        'checkIn': '09:00',
        'checkOut': '18:30',
        'isManual': false,
      };
      final manualLeaveMark = <String, dynamic>{
        'type': AppConstants.typeLeave,
        'hours': 0.0,
        'isManual': true,
      };

      final merged = CalendarMarkMerge.applyMark(apiDay, manualLeaveMark);

      expect(merged['type'], AppConstants.typeLeave);
      expect(merged['hours'], 0.0);
      expect(merged['isManual'], isTrue);
    });

    test('applies manual custom time and recalculates hours', () {
      final apiDay = <String, dynamic>{
        'type': AppConstants.typeWorkday,
        'hours': 7.0,
        'apiHours': 7.0,
        'isManual': false,
      };
      final manualMark = <String, dynamic>{
        'type': AppConstants.typeCustom,
        'isManual': true,
        'customCheckIn': '10:00',
        'customCheckOut': '19:30',
      };

      final merged = CalendarMarkMerge.applyMark(apiDay, manualMark);

      expect(merged['type'], AppConstants.typeCustom);
      expect(merged['isManual'], isTrue);
      expect(merged['customCheckIn'], '10:00');
      expect(merged['customCheckOut'], '19:30');
      expect(merged['hours'], 8.5);
    });

    test(
      'restores default type and API hours without keeping manual fields',
      () {
        final markedDay = <String, dynamic>{
          'type': AppConstants.typeCustom,
          'hours': 8.5,
          'apiHours': 6.75,
          'isManual': true,
          'isOvertime': true,
          'isCustomHours': true,
          'customCheckIn': '10:00',
          'customCheckOut': '19:30',
          'checkIn': '09:30',
          'checkOut': '17:15',
        };

        final restored = CalendarMarkMerge.restoreDefault(
          markedDay,
          AppConstants.typeWorkday,
        );

        expect(restored['type'], AppConstants.typeWorkday);
        expect(restored['hours'], 6.75);
        expect(restored['isManual'], isFalse);
        expect(restored.containsKey('isOvertime'), isFalse);
        expect(restored.containsKey('isCustomHours'), isFalse);
        expect(restored.containsKey('customCheckIn'), isFalse);
        expect(restored.containsKey('customCheckOut'), isFalse);
        expect(restored['checkIn'], '09:30');
        expect(restored['checkOut'], '17:15');
      },
    );

    test(
      'restores default from live attendance hours when API hours are absent',
      () {
        final markedDay = <String, dynamic>{
          'type': AppConstants.typeLeave,
          'hours': 0.0,
          'isManual': true,
        };
        final attendance = <String, dynamic>{
          'hours': 7.25,
          'checkInTime': '09:10',
          'checkOutTime': '17:25',
        };

        final restored = CalendarMarkMerge.restoreDefault(
          markedDay,
          AppConstants.typeWorkday,
          attendanceData: attendance,
        );

        expect(restored['hours'], 7.25);
        expect(restored['checkIn'], '09:10');
        expect(restored['checkOut'], '17:25');
        expect(restored['isManual'], isFalse);
      },
    );
  });
}
