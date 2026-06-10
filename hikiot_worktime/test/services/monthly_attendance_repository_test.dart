import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/monthly_attendance_repository.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:hikiot_worktime/utils/smart_day_type_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MonthlyAttendanceRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'loads persisted month cache without touching the monthly API',
      () async {
        final storage = StorageService();
        await storage.saveMonthlyData('team-1', '2026-06', {
          '2026-06-01': {
            'hours': 8.0,
            'type': AppConstants.typeWorkday,
            'isManual': false,
          },
        });

        var apiCalled = false;
        final repository = MonthlyAttendanceRepository(
          storage: storage,
          loadMonthlyAttendance: (_, _) async {
            apiCalled = true;
            return {};
          },
          loadDailyAttendance: (_, _) async => null,
        );

        final result = await repository.loadMonth(
          teamNo: 'team-1',
          personNo: 'person-1',
          selectedMonth: DateTime(2026, 6),
        );

        expect(result.source, MonthlyAttendanceLoadSource.persistentCache);
        expect(apiCalled, isFalse);
        expect(result.monthlyData['2026-06-01']?['hours'], 8.0);
        expect(
          result.monthlyData['2026-06-01']?[SmartDayTypeHelper
              .dataSourceStatusKey],
          isNull,
        );
      },
    );

    test(
      'force refresh merges API data, saved marks, and persists cache',
      () async {
        final storage = StorageService();
        await storage.saveHolidayPlan(2026, {
          '2026-06-01': AppConstants.typeWorkday,
        });
        await storage.saveSingleCalendarMark('team-1', '2026-06-02', {
          'type': AppConstants.typeBusinessTrip,
          'isManual': true,
        });

        final repository = MonthlyAttendanceRepository(
          storage: storage,
          loadMonthlyAttendance: (_, _) async => {
            'personName': '测试用户',
            'dailyRecords': [
              {
                'date': '2026-06-01',
                'hours': 1.0,
                'checkIn': '09:00',
                'checkOut': null,
                'isRestDay': true,
                SmartDayTypeHelper.dataSourceStatusKey:
                    SmartDayTypeHelper.dataSourceStatusApiConfirmed,
              },
            ],
          },
          loadDailyAttendance: (_, _) async => null,
        );

        final result = await repository.loadMonth(
          teamNo: 'team-1',
          personNo: 'person-1',
          selectedMonth: DateTime(2026, 6),
          forceRefresh: true,
        );

        expect(result.source, MonthlyAttendanceLoadSource.api);
        expect(result.personName, '测试用户');
        expect(result.holidayPlan['2026-06-01'], AppConstants.typeRestDay);
        expect(
          result.monthlyData['2026-06-01']?['type'],
          AppConstants.typeOvertime,
        );
        expect(
          result.monthlyData['2026-06-02']?['type'],
          AppConstants.typeBusinessTrip,
        );

        final cached = await storage.loadMonthlyData('team-1', '2026-06');
        expect(cached?['2026-06-02']?['hours'], AppConstants.businessTripHours);

        final holidayPlan = await storage.getHolidayPlan(2026);
        expect(holidayPlan['2026-06-01'], AppConstants.typeRestDay);
        expect(await storage.loadUserName(), '测试用户');
      },
    );

    test('saves and restores day settings through the repository', () async {
      final storage = StorageService();
      final repository = MonthlyAttendanceRepository(
        storage: storage,
        loadMonthlyAttendance: (_, _) async => {},
        loadDailyAttendance: (_, _) async => null,
      );
      final currentData = {
        '2026-06-08': {
          'hours': 8.0,
          'apiHours': 8.0,
          'type': AppConstants.typeWorkday,
          'isManual': false,
        },
      };

      final saved = await repository.saveDaySettings(
        teamNo: 'team-1',
        selectedMonth: DateTime(2026, 6),
        currentData: currentData,
        dateStr: '2026-06-08',
        type: AppConstants.typeCustom,
        isOvertime: false,
        isCustomHours: true,
        customCheckIn: '10:00',
        customCheckOut: '19:30',
      );

      expect(saved.monthlyData['2026-06-08']?['type'], AppConstants.typeCustom);
      expect(saved.monthlyData['2026-06-08']?['hours'], 8.5);
      var marks = await storage.loadCalendarMarks('team-1');
      expect(marks['2026-06-08']?['isManual'], isTrue);

      final restored = await repository.restoreDefaultType(
        teamNo: 'team-1',
        selectedMonth: DateTime(2026, 6),
        currentData: saved.monthlyData,
        holidayPlan: {'2026-06-08': AppConstants.typeWorkday},
        dateStr: '2026-06-08',
      );

      expect(
        restored.monthlyData['2026-06-08']?['type'],
        AppConstants.typeWorkday,
      );
      expect(restored.monthlyData['2026-06-08']?['hours'], 8.0);
      marks = await storage.loadCalendarMarks('team-1');
      expect(marks.containsKey('2026-06-08'), isFalse);
    });

    test(
      'safe smart update reports background errors without throwing',
      () async {
        final storage = StorageService();
        final repository = MonthlyAttendanceRepository(
          storage: storage,
          loadMonthlyAttendance: (_, _) async => {},
          loadDailyAttendance: (_, _) async => throw StateError('network down'),
        );

        final result = await repository.smartQuickUpdateSafely(
          teamNo: 'team-1',
          personNo: 'person-1',
          selectedMonth: DateTime(2026, 6),
          currentData: {
            '2026-06-10': {
              'hours': 0.0,
              'type': AppConstants.typeWorkday,
              'isManual': false,
            },
          },
          now: DateTime(2026, 6, 10),
        );

        expect(result.updateResult, isNull);
        expect(result.error, isA<StateError>());
        expect(result.stackTrace, isNotNull);
      },
    );
  });
}
