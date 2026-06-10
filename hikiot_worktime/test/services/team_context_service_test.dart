import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/storage_service.dart';
import 'package:hikiot_worktime/services/team_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TeamContextService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('uses saved team when it still exists in account teams', () async {
      final storage = StorageService();
      await storage.saveSelectedTeam('team-2');
      var changedTeamNo = '';
      var chooserCalled = false;

      final service = TeamContextService(
        storage: storage,
        loadAccountDetail: () async => _accountDetail(),
        changeTeam: (teamNo) async {
          changedTeamNo = teamNo;
          return true;
        },
      );

      final result = await service.initialize(
        chooseTeam: (_) async {
          chooserCalled = true;
          return null;
        },
      );

      expect(result.teamNo, 'team-2');
      expect(result.personNo, 'person-2');
      expect(result.teamName, '二队');
      expect(result.userName, '测试用户');
      expect(result.teamChanged, isFalse);
      expect(changedTeamNo, 'team-2');
      expect(chooserCalled, isFalse);
      expect(await storage.loadTeamNo(), 'team-2');
      expect(await storage.loadPersonNo(), 'person-2');
      expect(await storage.loadTeamName(), '二队');
    });

    test('asks caller to choose when saved team is absent', () async {
      final storage = StorageService();
      await storage.saveSelectedTeam('missing-team');

      final service = TeamContextService(
        storage: storage,
        loadAccountDetail: () async => _accountDetail(),
        changeTeam: (_) async => true,
      );

      final result = await service.initialize(
        chooseTeam: (teams) async =>
            teams.singleWhere((team) => team['teamNo'] == 'team-1'),
      );

      expect(result.teamNo, 'team-1');
      expect(result.teamChanged, isTrue);
      expect(await storage.loadSelectedTeam(), 'team-1');
    });

    test(
      'does not silently choose first team when chooser returns null',
      () async {
        final storage = StorageService();
        await storage.saveSelectedTeam('missing-team');
        var changeCalls = 0;

        final service = TeamContextService(
          storage: storage,
          loadAccountDetail: () async => _accountDetail(),
          changeTeam: (_) async {
            changeCalls++;
            return true;
          },
        );

        await expectLater(
          () => service.initialize(chooseTeam: (_) async => null),
          throwsA(
            predicate<Object>((error) => error.toString().contains('必须选择团队')),
          ),
        );
        expect(changeCalls, 0);
        expect(await storage.loadSelectedTeam(), 'missing-team');
      },
    );

    test(
      'requires an explicit chooser when multiple teams have no saved team',
      () async {
        var changeCalls = 0;
        final service = TeamContextService(
          storage: StorageService(),
          loadAccountDetail: () async => _accountDetail(),
          changeTeam: (_) async {
            changeCalls++;
            return true;
          },
        );

        await expectLater(
          () => service.initialize(),
          throwsA(
            predicate<Object>((error) => error.toString().contains('必须选择团队')),
          ),
        );
        expect(changeCalls, 0);
      },
    );

    test(
      'does not call changeTeam again when switching to current team',
      () async {
        final storage = StorageService();
        await storage.saveTeamContext(
          teamNo: 'team-1',
          personNo: 'person-1',
          teamName: '一队',
        );
        var changeCalls = 0;

        final service = TeamContextService(
          storage: storage,
          loadAccountDetail: () async => _accountDetail(),
          changeTeam: (_) async {
            changeCalls++;
            return true;
          },
        );

        final result = await service.switchTo({
          'teamNo': 'team-1',
          'personNo': 'person-1',
          'teamName': '一队',
        });

        expect(result.teamChanged, isFalse);
        expect(changeCalls, 0);
      },
    );

    test('loads team candidates without changing active team', () async {
      var changeCalls = 0;
      final service = TeamContextService(
        storage: StorageService(),
        loadAccountDetail: () async => _accountDetail(),
        changeTeam: (_) async {
          changeCalls++;
          return true;
        },
      );

      final teams = await service.loadTeams();

      expect(teams.map((team) => team['teamNo']), ['team-1', 'team-2']);
      expect(changeCalls, 0);
    });
  });
}

Map<String, dynamic> _accountDetail() {
  return {
    'nickName': '测试用户',
    'teamInfoList': [
      {'teamNo': 'team-1', 'personNo': 'person-1', 'teamName': '一队'},
      {'teamNo': 'team-2', 'personNo': 'person-2', 'teamName': '二队'},
    ],
  };
}
