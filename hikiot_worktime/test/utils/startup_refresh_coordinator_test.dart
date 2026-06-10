import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/startup_refresh_coordinator.dart';

void main() {
  group('StartupRefreshCoordinator', () {
    test('refreshes daily data only after session initialization', () async {
      final events = <String>[];

      await StartupRefreshCoordinator.run(
        initializeSession: () async {
          events.add('initialize-session');
        },
        refreshDaily: () async {
          events.add('refresh-daily');
        },
        refreshMonthly: () async {
          events.add('refresh-monthly');
        },
        isMounted: () => true,
      );

      expect(events, [
        'initialize-session',
        'refresh-daily',
        'refresh-monthly',
      ]);
    });

    test('does not refresh child pages after the owner is unmounted', () async {
      final events = <String>[];
      var mounted = true;

      await StartupRefreshCoordinator.run(
        initializeSession: () async {
          events.add('initialize-session');
          mounted = false;
        },
        refreshDaily: () async {
          events.add('refresh-daily');
        },
        refreshMonthly: () async {
          events.add('refresh-monthly');
        },
        isMounted: () => mounted,
      );

      expect(events, ['initialize-session']);
    });
  });
}
