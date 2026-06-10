import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'punch_reminder_service.dart';
import 'storage_service.dart';

/// 通知服务 - 管理本地通知和定时闹钟
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 闹钟ID
  static const int morningAlarmId = 1001;
  static const int eveningAlarmId = 1002;
  static const int testAlarmId = 1003;

  // 通知渠道 - 高优先级
  static const String channelId = 'punch_reminder_high';
  static const String channelName = '打卡提醒';
  static const String channelDesc = '上下班打卡提醒通知（高优先级）';

  /// 初始化通知服务
  Future<void> initialize() async {
    // Android 设置
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS 设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 初始化 AlarmManager
    await AndroidAlarmManager.initialize();

    // 创建通知渠道 (Android 8.0+)
    await _createNotificationChannel();
  }

  /// 创建高优先级通知渠道
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // 删除旧渠道（如果存在）
    await androidPlugin.deleteNotificationChannel('punch_reminder');

    // 创建高优先级通知渠道，使用系统默认铃声
    final channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.max, // 最高优先级，确保悬浮通知
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      // 设置振动模式: 延迟0ms, 振动500ms, 暂停200ms, 振动500ms
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    // 点击通知后的处理，可以打开APP
  }

  /// 请求通知权限
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// 请求精确闹钟权限 (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.request();
      return status.isGranted;
    }
    return true;
  }

  /// 检查所有必要权限
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'notification': await Permission.notification.isGranted,
      'exactAlarm': await Permission.scheduleExactAlarm.isGranted,
      'ignoreBatteryOptimizations':
          await Permission.ignoreBatteryOptimizations.isGranted,
    };
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    }
    return true;
  }

  /// 发送通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Android 通知配置 - 最高优先级
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max, // 最高优先级
      priority: Priority.max, // 最高优先级
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      // 使用系统默认通知铃声（不指定sound则使用系统默认）
      // 全屏意图 - 确保在锁屏时也能显示悬浮通知
      fullScreenIntent: true,
      // 设置振动模式: 延迟0ms, 振动500ms, 暂停200ms, 振动500ms
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      // 显示时间
      showWhen: true,
      // 通知类别 - 提醒类
      category: AndroidNotificationCategory.reminder,
      // 可见性 - 在锁屏上完整显示
      visibility: NotificationVisibility.public,
      // 自动取消
      autoCancel: true,
      // 每次都提醒（声音+振动）
      onlyAlertOnce: false,
      // 使用LED闪烁
      ledOnMs: 1000,
      ledOffMs: 500,
      ledColor: const Color(0xFF2196F3),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // 关键警报 - iOS可在静音模式下发声
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details);
  }

  /// 设置上班提醒闹钟
  Future<void> scheduleMorningAlarm(int hour, int minute) async {
    await _cancelAlarm(morningAlarmId);

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // 如果今天的时间已过，设置为明天
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      morningAlarmId,
      _morningAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    // 保存设置
    await StorageService().saveMorningReminder(
      enabled: true,
      hour: hour,
      minute: minute,
    );
  }

  /// 设置下班提醒闹钟
  Future<void> scheduleEveningAlarm(int hour, int minute) async {
    await _cancelAlarm(eveningAlarmId);

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // 如果今天的时间已过，设置为明天
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      eveningAlarmId,
      _eveningAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    // 保存设置
    await StorageService().saveEveningReminder(
      enabled: true,
      hour: hour,
      minute: minute,
    );
  }

  /// 取消闹钟
  Future<void> _cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
  }

  /// 取消上班提醒
  Future<void> cancelMorningAlarm() async {
    await _cancelAlarm(morningAlarmId);
    final settings = await StorageService().loadReminderSettings();
    await StorageService().saveMorningReminder(
      enabled: false,
      hour: settings.morningHour,
      minute: settings.morningMinute,
    );
  }

  /// 取消下班提醒
  Future<void> cancelEveningAlarm() async {
    await _cancelAlarm(eveningAlarmId);
    final settings = await StorageService().loadReminderSettings();
    await StorageService().saveEveningReminder(
      enabled: false,
      hour: settings.eveningHour,
      minute: settings.eveningMinute,
    );
  }

  /// 设置测试闹钟 (10秒后触发)
  Future<void> scheduleTestAlarm() async {
    await _cancelAlarm(testAlarmId);

    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      testAlarmId,
      _testAlarmCallback,
      exact: true,
      wakeup: true,
    );
  }

  /// 重新注册所有闹钟 (开机后调用)
  Future<void> rescheduleAllAlarms() async {
    final settings = await StorageService().loadReminderSettings();

    // 上班提醒
    if (settings.morningEnabled) {
      await scheduleMorningAlarm(settings.morningHour, settings.morningMinute);
    }

    // 下班提醒
    if (settings.eveningEnabled) {
      await scheduleEveningAlarm(settings.eveningHour, settings.eveningMinute);
    }
  }
}

/// 上班闹钟回调 (必须是顶级函数)
@pragma('vm:entry-point')
Future<void> _morningAlarmCallback() async {
  // 确保Flutter绑定初始化
  DartPluginRegistrant.ensureInitialized();

  await PunchReminderService.checkMorningPunch();

  // 重新注册明天的闹钟
  final settings = await StorageService().loadReminderSettings();
  if (settings.morningEnabled) {
    await NotificationService().scheduleMorningAlarm(
      settings.morningHour,
      settings.morningMinute,
    );
  }
}

/// 下班闹钟回调 (必须是顶级函数)
@pragma('vm:entry-point')
Future<void> _eveningAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();

  await PunchReminderService.checkEveningPunch();

  // 重新注册明天的闹钟
  final settings = await StorageService().loadReminderSettings();
  if (settings.eveningEnabled) {
    await NotificationService().scheduleEveningAlarm(
      settings.eveningHour,
      settings.eveningMinute,
    );
  }
}

/// 测试闹钟回调 (必须是顶级函数)
@pragma('vm:entry-point')
Future<void> _testAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();

  await PunchReminderService.sendTestNotification();
}
