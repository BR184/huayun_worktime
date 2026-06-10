import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/date_helper.dart';

void main() {
  group('DateHelper', () {
    setUp(() {
      DateHelper.crossDayMinutes = 4 * 60;
    });

    test('uses natural date before the cross-day reminder time', () {
      final workDate = DateHelper.getWorkDate(now: DateTime(2026, 6, 10, 1));

      expect(workDate, DateTime(2026, 6, 10));
    });

    test('detects punches inside the cross-day reminder window', () {
      expect(DateHelper.isCrossDayReminderPunchTime('00:30'), isTrue);
      expect(DateHelper.isCrossDayReminderPunchTime('03:59'), isTrue);
      expect(DateHelper.isCrossDayReminderPunchTime('00:00'), isFalse);
      expect(DateHelper.isCrossDayReminderPunchTime('04:00'), isFalse);
      expect(DateHelper.isCrossDayReminderPunchTime('23:30'), isFalse);
      expect(DateHelper.isCrossDayReminderPunchTime('-'), isFalse);
    });
  });
}
