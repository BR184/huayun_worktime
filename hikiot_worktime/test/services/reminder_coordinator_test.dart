import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/reminder_coordinator.dart';

void main() {
  group('ReminderCoordinator', () {
    test('does not schedule when notification permission is denied', () async {
      final scheduler = _FakeReminderScheduler(notificationPermission: false);
      final coordinator = ReminderCoordinator(scheduler: scheduler);

      final result = await coordinator.setMorningReminder(
        enabled: true,
        hour: 8,
        minute: 55,
      );

      expect(result, ReminderToggleResult.notificationPermissionDenied);
      expect(scheduler.initialized, isTrue);
      expect(scheduler.morningScheduleCalls, isEmpty);
    });

    test('does not schedule when exact alarm permission is denied', () async {
      final scheduler = _FakeReminderScheduler(exactAlarmPermission: false);
      final coordinator = ReminderCoordinator(scheduler: scheduler);

      final result = await coordinator.setEveningReminder(
        enabled: true,
        hour: 21,
        minute: 0,
      );

      expect(result, ReminderToggleResult.exactAlarmPermissionDenied);
      expect(scheduler.eveningScheduleCalls, isEmpty);
    });

    test('schedules reminders after permissions are granted', () async {
      final scheduler = _FakeReminderScheduler();
      final coordinator = ReminderCoordinator(scheduler: scheduler);

      final morning = await coordinator.setMorningReminder(
        enabled: true,
        hour: 8,
        minute: 50,
      );
      final evening = await coordinator.setEveningReminder(
        enabled: true,
        hour: 20,
        minute: 30,
      );

      expect(morning, ReminderToggleResult.enabled);
      expect(evening, ReminderToggleResult.enabled);
      expect(scheduler.morningScheduleCalls, ['08:50']);
      expect(scheduler.eveningScheduleCalls, ['20:30']);
    });

    test('cancels reminders when disabled', () async {
      final scheduler = _FakeReminderScheduler();
      final coordinator = ReminderCoordinator(scheduler: scheduler);

      final morning = await coordinator.setMorningReminder(
        enabled: false,
        hour: 8,
        minute: 50,
      );
      final evening = await coordinator.setEveningReminder(
        enabled: false,
        hour: 20,
        minute: 30,
      );

      expect(morning, ReminderToggleResult.disabled);
      expect(evening, ReminderToggleResult.disabled);
      expect(scheduler.morningCancelled, isTrue);
      expect(scheduler.eveningCancelled, isTrue);
      expect(scheduler.initialized, isFalse);
    });
  });
}

class _FakeReminderScheduler implements ReminderScheduler {
  _FakeReminderScheduler({
    this.notificationPermission = true,
    this.exactAlarmPermission = true,
  });

  final bool notificationPermission;
  final bool exactAlarmPermission;
  bool initialized = false;
  bool morningCancelled = false;
  bool eveningCancelled = false;
  final List<String> morningScheduleCalls = <String>[];
  final List<String> eveningScheduleCalls = <String>[];

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> requestNotificationPermission() async => notificationPermission;

  @override
  Future<bool> requestExactAlarmPermission() async => exactAlarmPermission;

  @override
  Future<void> scheduleMorningAlarm(int hour, int minute) async {
    morningScheduleCalls.add(_format(hour, minute));
  }

  @override
  Future<void> scheduleEveningAlarm(int hour, int minute) async {
    eveningScheduleCalls.add(_format(hour, minute));
  }

  @override
  Future<void> cancelMorningAlarm() async {
    morningCancelled = true;
  }

  @override
  Future<void> cancelEveningAlarm() async {
    eveningCancelled = true;
  }

  String _format(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
