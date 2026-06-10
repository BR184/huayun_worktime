import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/constants.dart';
import 'package:hikiot_worktime/services/settings_repository.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'loads a complete settings snapshot for the settings screen',
      () async {
        final storage = StorageService();
        await storage.saveToken('token-1');
        await storage.saveTeamContext(
          teamNo: 'team-1',
          personNo: 'person-1',
          teamName: '研发团队',
        );
        await storage.saveUserName('测试用户');
        await storage.saveSmartSort(false);
        await storage.saveBaseTarget(150);
        await storage.saveExtendedTargetRange(true);
        await storage.saveDebugToolsEnabled(true);
        await storage.saveMorningReminder(enabled: true, hour: 8, minute: 45);

        final snapshot = await SettingsRepository(storage: storage).load();

        expect(snapshot.token, 'token-1');
        expect(snapshot.teamNo, 'team-1');
        expect(snapshot.teamName, '研发团队');
        expect(snapshot.userName, '测试用户');
        expect(snapshot.smartSort, isFalse);
        expect(snapshot.baseTarget, 150);
        expect(snapshot.extendedTargetRange, isTrue);
        expect(snapshot.debugToolsEnabled, isTrue);
        expect(snapshot.reminderSettings.morningEnabled, isTrue);
        expect(snapshot.reminderSettings.morningHour, 8);
        expect(snapshot.reminderSettings.morningMinute, 45);
        expect(snapshot.lunchStartTime, AppConstants.defaultLunchStart);
        expect(snapshot.lunchEndTime, AppConstants.defaultLunchEnd);
      },
    );

    test('saves lunch times through canonical settings storage', () async {
      final storage = StorageService();
      final repository = SettingsRepository(storage: storage);

      await repository.saveLunchTimes(start: '11:30', end: '12:15');

      final settings = await storage.loadSettings();
      expect(settings[StorageKeys.lunchStartTime], '11:30');
      expect(settings[StorageKeys.lunchEndTime], '12:15');
      expect(settings['lunchStartTime'], '11:30');
      expect(settings['lunchEndTime'], '12:15');
    });

    test('saves target settings and clamps base target when range is closed', () async {
      final storage = StorageService();
      final repository = SettingsRepository(storage: storage);

      await repository.saveTargetSettings(
        extendedTargetRange: false,
        baseTarget: 240,
      );

      expect(await storage.loadExtendedTargetRange(), isFalse);
      expect(await storage.loadBaseTarget(), 160);
    });

    test('saves screen toggles and reminder time through the repository', () async {
      final storage = StorageService();
      final repository = SettingsRepository(storage: storage);

      await repository.saveSmartSort(false);
      await repository.saveDebugToolsEnabled(true);
      await repository.saveOnboardingCompleted(false);
      await repository.saveReminderTime(
        isMorning: true,
        enabled: false,
        hour: 9,
        minute: 10,
      );

      final reminderSettings = await storage.loadReminderSettings();
      expect(await storage.loadSmartSort(), isFalse);
      expect(await storage.loadDebugToolsEnabled(), isTrue);
      expect(await storage.loadOnboardingCompleted(), isFalse);
      expect(reminderSettings.morningEnabled, isFalse);
      expect(reminderSettings.morningHour, 9);
      expect(reminderSettings.morningMinute, 10);
    });

    test('loads and saves token for settings-only debug actions', () async {
      final storage = StorageService();
      final repository = SettingsRepository(storage: storage);

      await repository.saveTokenForDebug('token-2');

      expect(await repository.loadToken(), 'token-2');
      expect(await storage.loadToken(), 'token-2');
    });
  });
}
