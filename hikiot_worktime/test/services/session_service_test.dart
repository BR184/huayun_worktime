import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/session_service.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SessionService', () {
    late StorageService storage;
    late List<String> remoteLogoutTokens;
    var clearWebSessionCount = 0;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      remoteLogoutTokens = <String>[];
      clearWebSessionCount = 0;
    });

    SessionService createService({
      bool failRemoteLogout = false,
      bool failClearWebSession = false,
    }) {
      return SessionService(
        storage: storage,
        remoteLogout: (token) async {
          remoteLogoutTokens.add(token);
          if (failRemoteLogout) {
            throw Exception('network down');
          }
        },
        clearWebSession: () async {
          clearWebSessionCount++;
          if (failClearWebSession) {
            throw Exception('cookie api crashed');
          }
        },
      );
    }

    test('logs out remotely, clears web session and local auth', () async {
      await storage.saveToken('token-1');
      await storage.saveUserName('张三');
      final service = createService();

      await service.logout();

      expect(remoteLogoutTokens, ['token-1']);
      expect(clearWebSessionCount, 1);
      expect(await storage.loadToken(), isNull);
      expect(await storage.loadUserName(), isNull);
    });

    test(
      'still clears web session and local auth when remote logout fails',
      () async {
        await storage.saveToken('token-1');
        final service = createService(failRemoteLogout: true);

        await service.logout();

        expect(remoteLogoutTokens, ['token-1']);
        expect(clearWebSessionCount, 1);
        expect(await storage.loadToken(), isNull);
      },
    );

    test('still clears local auth when web session cleanup fails', () async {
      await storage.saveToken('token-1');
      await storage.saveUserName('张三');
      final service = createService(failClearWebSession: true);

      await service.logout();

      expect(remoteLogoutTokens, ['token-1']);
      expect(clearWebSessionCount, 1);
      expect(await storage.loadToken(), isNull);
      expect(await storage.loadUserName(), isNull);
    });

    test('logout clears team and person context residue', () async {
      // 构造完整的旧账号认证上下文
      await storage.saveToken('token-1');
      await storage.saveUserName('张三');
      await storage.saveTeamContext(
        teamNo: 'team-1',
        personNo: 'person-1',
        teamName: '研发团队',
      );
      await storage.saveSelectedTeam('team-1');
      final service = createService();

      await service.logout();

      // 认证上下文全部清理，换账号后不会读到旧账号的 teamNo/personNo
      expect(await storage.loadToken(), isNull);
      expect(await storage.loadUserName(), isNull);
      expect(await storage.loadTeamNo(), isNull);
      expect(await storage.loadPersonNo(), isNull);
      expect(await storage.loadTeamName(), isNull);
      expect(await storage.loadSelectedTeam(), isNull);
    });

    test(
      'does not call remote logout when token is missing or invalid debug token',
      () async {
        final service = createService();

        await service.clearRemoteAndWebSession(null);
        await service.clearRemoteAndWebSession('');
        await service.clearRemoteAndWebSession('   ');
        await service.clearRemoteAndWebSession(
          'INVALID_TOKEN_FOR_DEBUG_TESTING_12345',
        );
        await service.clearRemoteAndWebSession(
          'invalid_token_for_debug_testing_12345',
        );

        expect(remoteLogoutTokens, isEmpty);
        expect(clearWebSessionCount, 5);
      },
    );

    test('trims token before calling remote logout', () async {
      final service = createService();

      await service.clearRemoteAndWebSession('  token-1  ');

      expect(remoteLogoutTokens, ['token-1']);
      expect(clearWebSessionCount, 1);
    });
  });
}
