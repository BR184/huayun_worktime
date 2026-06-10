import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/monthly_attendance_merge_service.dart';
import 'package:hikiot_worktime/utils/smart_day_type_helper.dart';

void main() {
  group('MonthlyAttendanceMergeService', () {
    test(
      'builds month rows, applies native rest-day type and manual marks',
      () {
        final result = MonthlyAttendanceMergeService().merge(
          selectedMonth: DateTime(2026, 6),
          holidayPlan: {'2026-06-01': AppConstants.typeWorkday},
          monthlyStats: {
            'personName': '测试用户',
            'dailyRecords': [
              {
                'date': '2026-06-01',
                'hours': 0.0,
                'checkIn': '09:00',
                'checkOut': null,
                'isRestDay': true,
                SmartDayTypeHelper.dataSourceStatusKey:
                    SmartDayTypeHelper.dataSourceStatusApiConfirmed,
              },
            ],
          },
          savedMarks: {
            '2026-06-02': {
              'type': AppConstants.typeBusinessTrip,
              'isManual': true,
            },
          },
        );

        expect(result.personName, '测试用户');
        expect(result.holidayPlanChanged, isTrue);
        expect(result.holidayPlan['2026-06-01'], AppConstants.typeRestDay);
        expect(
          result.monthlyData['2026-06-01']?['type'],
          AppConstants.typeOvertime,
        );
        expect(
          result.monthlyData['2026-06-02']?['type'],
          AppConstants.typeBusinessTrip,
        );
        expect(
          result.monthlyData['2026-06-02']?['hours'],
          AppConstants.businessTripHours,
        );
        expect(result.monthlyData, hasLength(30));
      },
    );
  });
}
