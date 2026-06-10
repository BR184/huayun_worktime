import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:hikiot_worktime/utils/reminder_day_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReminderDayPolicy', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'skips reminder when holiday plan marks a weekday as rest day',
      () async {
        final storage = StorageService();
        await storage.saveHolidayPlan(2026, {
          '2026-06-10': AppConstants.typeRestDay,
        });
        final policy = ReminderDayPolicy(storage: storage);

        final shouldSkip = await policy.shouldSkipWorkReminder(
          DateTime(2026, 6, 10),
        );

        expect(shouldSkip, isTrue);
      },
    );

    test(
      'does not skip reminder when holiday plan marks weekend as workday',
      () async {
        final storage = StorageService();
        await storage.saveHolidayPlan(2026, {
          '2026-06-13': AppConstants.typeWorkday,
        });
        final policy = ReminderDayPolicy(storage: storage);

        final shouldSkip = await policy.shouldSkipWorkReminder(
          DateTime(2026, 6, 13),
        );

        expect(shouldSkip, isFalse);
      },
    );

    test('falls back to weekend when no holiday plan exists', () async {
      final policy = ReminderDayPolicy();

      expect(
        await policy.shouldSkipWorkReminder(DateTime(2026, 6, 13)),
        isTrue,
      );
      expect(
        await policy.shouldSkipWorkReminder(DateTime(2026, 6, 10)),
        isFalse,
      );
    });
  });
}
