import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/utils/smart_day_type_helper.dart';

void main() {
  group('SmartDayTypeHelper', () {
    test('does not infer leave from unconfirmed empty workday data', () {
      final inferred = SmartDayTypeHelper.inferDayType(
        currentType: AppConstants.typeWorkday,
        hours: 0,
        dateStr: '2026-06-09',
        hasCheckIn: false,
        currentWorkDate: DateTime(2026, 6, 10),
      );

      expect(inferred, isNull);
    });

    test('infers leave when API confirms an empty past workday', () {
      final inferred = SmartDayTypeHelper.inferDayType(
        currentType: AppConstants.typeWorkday,
        hours: 0,
        dateStr: '2026-06-09',
        hasCheckIn: false,
        dataSourceStatus: DayDataSourceStatus.apiConfirmed,
        currentWorkDate: DateTime(2026, 6, 10),
      );

      expect(inferred, AppConstants.typeLeave);
    });

    test('does not infer leave for the current natural work date', () {
      final inferred = SmartDayTypeHelper.inferDayType(
        currentType: AppConstants.typeWorkday,
        hours: 0,
        dateStr: '2026-06-09',
        hasCheckIn: false,
        dataSourceStatus: DayDataSourceStatus.apiConfirmed,
        currentWorkDate: DateTime(2026, 6, 9),
      );

      expect(inferred, isNull);
    });
  });
}
