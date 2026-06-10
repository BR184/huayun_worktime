import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/utils/smart_day_type_helper.dart';

void main() {
  group('SmartDayTypeHelper', () {
    test('does not infer leave from unconfirmed empty workday data', () {
      final yesterday = _formatDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      final inferred = SmartDayTypeHelper.inferDayType(
        currentType: AppConstants.typeWorkday,
        hours: 0,
        dateStr: yesterday,
        hasCheckIn: false,
      );

      expect(inferred, isNull);
    });

    test('infers leave when API confirms an empty past workday', () {
      final yesterday = _formatDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      final inferred = SmartDayTypeHelper.inferDayType(
        currentType: AppConstants.typeWorkday,
        hours: 0,
        dateStr: yesterday,
        hasCheckIn: false,
        dataSourceStatus: DayDataSourceStatus.apiConfirmed,
      );

      expect(inferred, AppConstants.typeLeave);
    });
  });
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
