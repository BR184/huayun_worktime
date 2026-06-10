import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/services/reminder_attendance_fetcher.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReminderAttendanceFetcher', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads today attendance through the unified daily loader', () async {
      final storage = StorageService();
      await storage.saveToken('token-1');
      await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

      final calls = <String>[];
      final fetcher = ReminderAttendanceFetcher(
        storage: storage,
        now: () => DateTime(2026, 6, 9, 8, 30),
        dailyAttendanceLoader: (token, date, personNo) async {
          calls.add('$token|$date|$personNo');
          return {'dailyDetail': <String, dynamic>{}};
        },
      );

      final result = await fetcher.fetchToday();

      expect(calls, ['token-1|2026-06-09|person-1']);
      expect(result.data, {'dailyDetail': <String, dynamic>{}});
      expect(result.tokenExpired, isFalse);
    });

    test('reports token expired when token is missing', () async {
      final fetcher = ReminderAttendanceFetcher(
        storage: StorageService(),
        dailyAttendanceLoader: (_, _, _) async {
          fail('loader should not be called without token');
        },
      );

      final result = await fetcher.fetchToday();

      expect(result.data, isNull);
      expect(result.tokenExpired, isTrue);
    });

    test(
      'does not report token expired when only person number is missing',
      () async {
        final storage = StorageService();
        await storage.saveToken('token-1');

        final fetcher = ReminderAttendanceFetcher(
          storage: storage,
          dailyAttendanceLoader: (_, _, _) async {
            fail('loader should not be called without personNo');
          },
        );

        final result = await fetcher.fetchToday();

        expect(result.data, isNull);
        expect(result.tokenExpired, isFalse);
      },
    );

    test('preserves token-expired failures from the daily loader', () async {
      final storage = StorageService();
      await storage.saveToken('token-1');
      await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

      final fetcher = ReminderAttendanceFetcher(
        storage: storage,
        dailyAttendanceLoader: (_, _, _) async {
          throw const TokenExpiredException();
        },
      );

      final result = await fetcher.fetchToday();

      expect(result.data, isNull);
      expect(result.tokenExpired, isTrue);
    });

    test('treats network failures as unavailable data', () async {
      final storage = StorageService();
      await storage.saveToken('token-1');
      await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

      final fetcher = ReminderAttendanceFetcher(
        storage: storage,
        dailyAttendanceLoader: (_, _, _) async {
          throw Exception('network down');
        },
      );

      final result = await fetcher.fetchToday();

      expect(result.data, isNull);
      expect(result.tokenExpired, isFalse);
    });
  });
}
