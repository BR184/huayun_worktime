import 'notification_service.dart';

/// 提醒开关操作结果。
enum ReminderToggleResult {
  enabled,
  disabled,
  notificationPermissionDenied,
  exactAlarmPermissionDenied,
}

/// 提醒调度器接口，隔离权限请求和 AlarmManager 调度细节。
abstract class ReminderScheduler {
  Future<void> initialize();

  Future<bool> requestNotificationPermission();

  Future<bool> requestExactAlarmPermission();

  Future<void> scheduleMorningAlarm(int hour, int minute);

  Future<void> scheduleEveningAlarm(int hour, int minute);

  Future<void> cancelMorningAlarm();

  Future<void> cancelEveningAlarm();
}

class _NotificationReminderScheduler implements ReminderScheduler {
  _NotificationReminderScheduler(this._notificationService);

  final NotificationService _notificationService;

  @override
  Future<void> initialize() {
    return _notificationService.initialize();
  }

  @override
  Future<bool> requestNotificationPermission() {
    return _notificationService.requestNotificationPermission();
  }

  @override
  Future<bool> requestExactAlarmPermission() {
    return _notificationService.requestExactAlarmPermission();
  }

  @override
  Future<void> scheduleMorningAlarm(int hour, int minute) {
    return _notificationService.scheduleMorningAlarm(hour, minute);
  }

  @override
  Future<void> scheduleEveningAlarm(int hour, int minute) {
    return _notificationService.scheduleEveningAlarm(hour, minute);
  }

  @override
  Future<void> cancelMorningAlarm() {
    return _notificationService.cancelMorningAlarm();
  }

  @override
  Future<void> cancelEveningAlarm() {
    return _notificationService.cancelEveningAlarm();
  }
}

/// 提醒设置协调器：统一处理权限闭环与实际调度。
class ReminderCoordinator {
  ReminderCoordinator({ReminderScheduler? scheduler})
    : _scheduler =
          scheduler ?? _NotificationReminderScheduler(NotificationService());

  final ReminderScheduler _scheduler;

  Future<ReminderToggleResult> setMorningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!enabled) {
      await _scheduler.cancelMorningAlarm();
      return ReminderToggleResult.disabled;
    }

    final permissionResult = await _ensurePermissions();
    if (permissionResult != null) return permissionResult;

    await _scheduler.scheduleMorningAlarm(hour, minute);
    return ReminderToggleResult.enabled;
  }

  Future<ReminderToggleResult> setEveningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!enabled) {
      await _scheduler.cancelEveningAlarm();
      return ReminderToggleResult.disabled;
    }

    final permissionResult = await _ensurePermissions();
    if (permissionResult != null) return permissionResult;

    await _scheduler.scheduleEveningAlarm(hour, minute);
    return ReminderToggleResult.enabled;
  }

  Future<ReminderToggleResult?> _ensurePermissions() async {
    await _scheduler.initialize();

    final hasNotificationPermission = await _scheduler
        .requestNotificationPermission();
    if (!hasNotificationPermission) {
      return ReminderToggleResult.notificationPermissionDenied;
    }

    final hasExactAlarmPermission = await _scheduler
        .requestExactAlarmPermission();
    if (!hasExactAlarmPermission) {
      return ReminderToggleResult.exactAlarmPermissionDenied;
    }

    return null;
  }
}
