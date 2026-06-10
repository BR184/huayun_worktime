import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/daily_attendance_repository.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:hikiot_worktime/utils/smart_day_type_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DailyAttendanceRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'returns missingTeam instead of touching API without a team context',
      () async {
        var apiCalled = false;
        final repository = DailyAttendanceRepository(
          storage: StorageService(),
          loadDailyAttendance: (_, _, _) async {
            apiCalled = true;
            return null;
          },
        );

        final result = await repository.load(
          DateTime(2026, 6, 8),
          workDate: DateTime(2026, 6, 8),
        );

        expect(result.status, DailyAttendanceLoadStatus.missingTeam);
        expect(apiCalled, isFalse);
      },
    );

    test(
      'builds default data, applies saved mark, and skips future API',
      () async {
        final storage = StorageService();
        await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');
        await storage.saveSingleCalendarMark('team-1', '2026-06-12', {
          'type': AppConstants.typeBusinessTrip,
          'isManual': true,
        });
        var apiCalled = false;

        final repository = DailyAttendanceRepository(
          storage: storage,
          loadDailyAttendance: (_, _, _) async {
            apiCalled = true;
            return null;
          },
        );

        final result = await repository.load(
          DateTime(2026, 6, 12),
          workDate: DateTime(2026, 6, 10),
        );

        expect(result.status, DailyAttendanceLoadStatus.loaded);
        expect(result.dayData['type'], AppConstants.typeBusinessTrip);
        expect(result.dayData['hours'], AppConstants.businessTripHours);
        expect(apiCalled, isFalse);
      },
    );

    test(
      'persists automatic overtime mark after confirmed rest-day punch',
      () async {
        final storage = StorageService();
        await storage.saveToken('token-1');
        await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');
        await storage.saveHolidayPlan(2026, {
          '2026-06-07': AppConstants.typeRestDay,
        });

        final repository = DailyAttendanceRepository(
          storage: storage,
          loadDailyAttendance: (_, _, _) async =>
              _dailyResponse(isRestDay: true, checkIn: '09:00', checkOut: null),
        );

        final result = await repository.load(
          DateTime(2026, 6, 7),
          workDate: DateTime(2026, 6, 7),
        );

        expect(result.status, DailyAttendanceLoadStatus.loaded);
        expect(result.dayData['type'], AppConstants.typeOvertime);
        expect(result.dayData['isManual'], isFalse);
        expect(
          result.attendanceData?[SmartDayTypeHelper.dataSourceStatusKey],
          SmartDayTypeHelper.dataSourceStatusApiConfirmed,
        );

        final marks = await storage.loadCalendarMarks('team-1');
        expect(marks['2026-06-07']?['type'], AppConstants.typeOvertime);
        expect(marks['2026-06-07']?['isManual'], isFalse);
      },
    );

    test(
      'reports missing token without classifying it as normal data',
      () async {
        final storage = StorageService();
        await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

        final repository = DailyAttendanceRepository(
          storage: storage,
          loadDailyAttendance: (_, _, _) async => _dailyResponse(),
        );

        final result = await repository.load(
          DateTime(2026, 6, 8),
          workDate: DateTime(2026, 6, 8),
        );

        expect(result.status, DailyAttendanceLoadStatus.missingToken);
        expect(result.attendanceData, isNull);
      },
    );

    test('saves and restores a manual day mark through the repository', () async {
      final storage = StorageService();
      await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');
      final repository = DailyAttendanceRepository(storage: storage);

      final saved = await repository.saveManualMark(
        selectedDate: DateTime(2026, 6, 8),
        markData: {
          'type': AppConstants.typeCustom,
          'isManual': true,
          'customCheckIn': '10:00',
          'customCheckOut': '19:30',
        },
      );

      expect(saved?.teamNo, 'team-1');
      expect(saved?.dayData['type'], AppConstants.typeCustom);
      expect(saved?.dayData['hours'], 8.5);
      var marks = await storage.loadCalendarMarks('team-1');
      expect(marks['2026-06-08']?['type'], AppConstants.typeCustom);

      final restored = await repository.restoreDefaultMark(
        selectedDate: DateTime(2026, 6, 8),
        currentData: saved!.dayData,
        holidayPlan: {'2026-06-08': AppConstants.typeWorkday},
        attendanceData: {'hours': 7.5},
      );

      expect(restored?.dayData['type'], AppConstants.typeWorkday);
      expect(restored?.dayData['hours'], 7.5);
      marks = await storage.loadCalendarMarks('team-1');
      expect(marks.containsKey('2026-06-08'), isFalse);
    });
  });
}

Map<String, dynamic> _dailyResponse({
  bool isRestDay = false,
  String? checkIn = '09:00',
  String? checkOut = '18:00',
}) {
  return {
    'dailyDetail': {
      'shiftId': isRestDay ? -1 : 1,
      'shiftName': isRestDay ? '休息' : '工作日',
      'shiftDetails': [
        {
          'clockInTime': checkIn,
          'clockOffTime': checkOut,
          'clockInStatusType': 0,
          'clockOffStatusType': 0,
        },
      ],
    },
  };
}
