import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:hikiot_worktime/utils/date_helper.dart';
import 'package:hikiot_worktime/utils/work_time_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService session context', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads team and person numbers together', () async {
      final storage = StorageService();

      await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

      expect(await storage.loadTeamNo(), 'team-1');
      expect(await storage.loadPersonNo(), 'person-1');
    });

    test(
      'clears person number when switching team without a new one',
      () async {
        final storage = StorageService();
        await storage.saveTeamContext(teamNo: 'team-1', personNo: 'person-1');

        // 切换团队但新团队没有 personNo 时，必须清除旧 personNo，
        // 避免换账号后沿用旧账号的人员编号
        await storage.saveTeamContext(teamNo: 'team-2');

        expect(await storage.loadTeamNo(), 'team-2');
        expect(await storage.loadPersonNo(), isNull);
      },
    );

    test(
      'clearAuthInfo wipes auth context but keeps global preferences',
      () async {
        final storage = StorageService();
        // 认证上下文
        await storage.saveToken('token-1');
        await storage.saveUserName('张三');
        await storage.saveTeamContext(
          teamNo: 'team-1',
          personNo: 'person-1',
          teamName: '研发团队',
        );
        await storage.saveSelectedTeam('team-1');
        // 全局偏好设置（登出后应保留）
        await storage.saveMorningReminder(enabled: true, hour: 8, minute: 50);
        await storage.saveBaseTarget(150);
        await storage.saveHapticModeIndex(1);
        await storage.saveSmartSort(false);

        await storage.clearAuthInfo();

        // 认证上下文全部清理（含 legacy key）
        expect(await storage.loadToken(), isNull);
        expect(await storage.loadUserName(), isNull);
        expect(await storage.loadTeamNo(), isNull);
        expect(await storage.loadPersonNo(), isNull);
        expect(await storage.loadTeamName(), isNull);
        expect(await storage.loadSelectedTeam(), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('current_team_no'), isNull);
        expect(prefs.getString('current_team_name'), isNull);
        expect(prefs.getString('current_user_name'), isNull);
        // 全局偏好设置未受影响
        expect(await storage.loadBaseTarget(), 150);
        expect(await storage.loadHapticModeIndex(), 1);
        expect(await storage.loadSmartSort(), isFalse);
        final reminder = await storage.loadReminderSettings();
        expect(reminder.morningEnabled, isTrue);
        expect(reminder.morningHour, 8);
        expect(reminder.morningMinute, 50);
      },
    );

    test('switching accounts does not leak old personNo or teamNo', () async {
      final storage = StorageService();
      // 账号A：登录、选择团队
      await storage.saveToken('token-a');
      await storage.saveTeamContext(
        teamNo: 'team-a',
        personNo: 'person-a',
        teamName: 'A团队',
      );
      await storage.saveSelectedTeam('team-a');
      // 账号A登出
      await storage.clearAuthInfo();

      // 账号B：重新登录、初始化团队上下文
      await storage.saveToken('token-b');
      await storage.saveTeamContext(
        teamNo: 'team-b',
        personNo: 'person-b',
        teamName: 'B团队',
      );

      // 新账号只能读到自己的上下文
      expect(await storage.loadToken(), 'token-b');
      expect(await storage.loadTeamNo(), 'team-b');
      expect(await storage.loadPersonNo(), 'person-b');
      expect(await storage.loadTeamName(), 'B团队');
      expect(await storage.loadSelectedTeam(), isNull);
    });
  });

  group('StorageService settings schema', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WorkTimeCalculator.lunchStartMinutes = 12 * 60;
      WorkTimeCalculator.lunchEndMinutes = 13 * 60;
      DateHelper.crossDayMinutes = AppConstants.defaultCrossDayMinutes;
    });

    test(
      'migrates legacy settings into canonical and compatibility keys',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageKeys.settings: jsonEncode({
            'targets': [100, 120],
            'lunch_break': {'start': '11:45', 'end': '12:30'},
            'day_change_hour': 3,
            'display_name': 'Alice',
          }),
        });
        final storage = StorageService();

        final settings = await storage.loadSettings();

        expect(settings[StorageKeys.lunchStartTime], '11:45');
        expect(settings[StorageKeys.lunchEndTime], '12:30');
        expect(settings[StorageKeys.crossDayMinutes], 180);
        expect(settings['lunchStartTime'], '11:45');
        expect(settings['lunchEndTime'], '12:30');
        expect(settings['day_change_hour'], 3);
        expect((settings['lunch_break'] as Map)['start'], '11:45');
        expect((settings['lunch_break'] as Map)['end'], '12:30');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(StorageKeys.lunchStartTime), '11:45');
        expect(prefs.getString(StorageKeys.lunchEndTime), '12:30');
        expect(prefs.getInt(StorageKeys.crossDayMinutes), 180);
      },
    );

    test(
      'saves settings to JSON and scalar keys used by startup tools',
      () async {
        final storage = StorageService();

        await storage.saveSettings({
          'lunchStartTime': '10:30',
          'lunchEndTime': '11:15',
          StorageKeys.crossDayMinutes: 150,
        });

        final settings = await storage.loadSettings();
        final prefs = await SharedPreferences.getInstance();

        expect(settings[StorageKeys.lunchStartTime], '10:30');
        expect(settings[StorageKeys.lunchEndTime], '11:15');
        expect(settings[StorageKeys.crossDayMinutes], 150);
        expect(settings['lunchStartTime'], '10:30');
        expect(settings['lunchEndTime'], '11:15');
        expect(prefs.getString(StorageKeys.lunchStartTime), '10:30');
        expect(prefs.getString(StorageKeys.lunchEndTime), '11:15');
        expect(prefs.getInt(StorageKeys.crossDayMinutes), 150);
      },
    );

    test('startup calculators read migrated legacy settings', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.settings: jsonEncode({
          'lunch_break': {'start': '11:20', 'end': '12:10'},
          'day_change_hour': 2,
        }),
      });

      await WorkTimeCalculator.reload();
      await DateHelper.reload();

      expect(WorkTimeCalculator.lunchStartMinutes, 11 * 60 + 20);
      expect(WorkTimeCalculator.lunchEndMinutes, 12 * 60 + 10);
      expect(DateHelper.crossDayMinutes, 2 * 60);
    });
  });

  group('StorageService reminder settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('migrates legacy alarm keys to canonical reminder keys', () async {
      SharedPreferences.setMockInitialValues({
        'morning_alarm_enabled': true,
        'morning_alarm_hour': 7,
        'morning_alarm_minute': 45,
        'evening_alarm_enabled': true,
        'evening_alarm_hour': 20,
        'evening_alarm_minute': 30,
      });
      final storage = StorageService();

      final settings = await storage.loadReminderSettings();

      expect(settings.morningEnabled, isTrue);
      expect(settings.morningHour, 7);
      expect(settings.morningMinute, 45);
      expect(settings.eveningEnabled, isTrue);
      expect(settings.eveningHour, 20);
      expect(settings.eveningMinute, 30);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageKeys.morningReminderEnabled), isTrue);
      expect(prefs.getString(StorageKeys.morningReminderTime), '07:45');
      expect(prefs.getBool(StorageKeys.eveningReminderEnabled), isTrue);
      expect(prefs.getString(StorageKeys.eveningReminderTime), '20:30');
    });

    test('saves canonical and legacy reminder keys together', () async {
      final storage = StorageService();

      await storage.saveMorningReminder(enabled: true, hour: 8, minute: 50);
      await storage.saveEveningReminder(enabled: false, hour: 19, minute: 40);

      final settings = await storage.loadReminderSettings();
      final prefs = await SharedPreferences.getInstance();

      expect(settings.morningEnabled, isTrue);
      expect(settings.morningHour, 8);
      expect(settings.morningMinute, 50);
      expect(settings.eveningEnabled, isFalse);
      expect(settings.eveningHour, 19);
      expect(settings.eveningMinute, 40);
      expect(prefs.getString(StorageKeys.morningReminderTime), '08:50');
      expect(prefs.getInt('morning_alarm_hour'), 8);
      expect(prefs.getInt('morning_alarm_minute'), 50);
      expect(prefs.getString(StorageKeys.eveningReminderTime), '19:40');
      expect(prefs.getInt('evening_alarm_hour'), 19);
      expect(prefs.getInt('evening_alarm_minute'), 40);
    });
  });

  group('StorageService UI and session flags', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('normalizes token when saving and loading', () async {
      final storage = StorageService();

      await storage.saveToken('  token-1  ');

      expect(await storage.loadToken(), 'token-1');

      await storage.saveToken('   ');

      expect(await storage.loadToken(), isNull);
    });

    test('migrates legacy blank token to logged-out state', () async {
      SharedPreferences.setMockInitialValues({StorageKeys.token: '   '});
      final storage = StorageService();

      expect(await storage.loadToken(), isNull);
    });

    test(
      'reads and writes onboarding completion through canonical key',
      () async {
        final storage = StorageService();

        expect(await storage.loadOnboardingCompleted(), isFalse);

        await storage.saveOnboardingCompleted(true);

        expect(await storage.loadOnboardingCompleted(), isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(StorageKeys.onboardingCompleted), isTrue);
      },
    );

    test('migrates legacy disclaimer flag to canonical key', () async {
      SharedPreferences.setMockInitialValues({'disclaimer_shown': true});
      final storage = StorageService();

      expect(await storage.loadDisclaimerAccepted(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageKeys.disclaimerAccepted), isTrue);
      expect(prefs.getBool('disclaimer_shown'), isTrue);
    });

    test('saves developer and target range settings through storage', () async {
      final storage = StorageService();

      await storage.saveExtendedTargetRange(true);
      await storage.saveDebugToolsEnabled(true);

      expect(await storage.loadExtendedTargetRange(), isTrue);
      expect(await storage.loadDebugToolsEnabled(), isTrue);
    });

    test(
      'saves team display info while keeping legacy current team keys',
      () async {
        final storage = StorageService();

        await storage.saveTeamContext(
          teamNo: 'team-1',
          personNo: 'person-1',
          teamName: '研发团队',
        );

        expect(await storage.loadTeamNo(), 'team-1');
        expect(await storage.loadPersonNo(), 'person-1');
        expect(await storage.loadTeamName(), '研发团队');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('current_team_no'), 'team-1');
        expect(prefs.getString('current_team_name'), '研发团队');
      },
    );

    test('loads team name from legacy current team key', () async {
      SharedPreferences.setMockInitialValues({'current_team_name': '旧团队'});
      final storage = StorageService();

      expect(await storage.loadTeamName(), '旧团队');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.teamName), '旧团队');
    });

    test('saves and loads haptic mode index through canonical key', () async {
      final storage = StorageService();

      expect(await storage.loadHapticModeIndex(), 0);

      await storage.saveHapticModeIndex(2);

      expect(await storage.loadHapticModeIndex(), 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(StorageKeys.hapticMode), 2);
    });

    test('saves and loads commute mode with free default', () async {
      final storage = StorageService();

      // 默认自由出行
      expect(await storage.loadCommuteMode(), 'free');

      await storage.saveCommuteMode('metro');
      expect(await storage.loadCommuteMode(), 'metro');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.commuteMode), 'metro');
    });

    test('saves and loads metro direction with index zero default', () async {
      final storage = StorageService();

      expect(await storage.loadCommuteMetroDirection(), 0);

      await storage.saveCommuteMetroDirection(2);
      expect(await storage.loadCommuteMetroDirection(), 2);
    });

    test('saves and loads metro walk minutes clamped to 4~10', () async {
      final storage = StorageService();

      // 默认 7 分钟
      expect(await storage.loadCommuteMetroWalkMinutes(), 7);

      await storage.saveCommuteMetroWalkMinutes(9);
      expect(await storage.loadCommuteMetroWalkMinutes(), 9);

      // 越界值被收敛到范围
      await storage.saveCommuteMetroWalkMinutes(3);
      expect(await storage.loadCommuteMetroWalkMinutes(), 4);
      await storage.saveCommuteMetroWalkMinutes(15);
      expect(await storage.loadCommuteMetroWalkMinutes(), 10);
    });
  });
}
