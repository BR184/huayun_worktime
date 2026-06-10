import 'storage_service.dart';

typedef AccountDetailLoader = Future<Map<String, dynamic>?> Function();
typedef TeamChanger = Future<bool> Function(String teamNo);
typedef TeamChooser =
    Future<Map<String, dynamic>?> Function(List<Map<String, dynamic>> teams);

class TeamContext {
  const TeamContext({
    required this.teamNo,
    required this.teamName,
    required this.teamChanged,
    this.personNo,
    this.userName,
  });

  final String teamNo;
  final String teamName;
  final String? personNo;
  final String? userName;
  final bool teamChanged;
}

class TeamSelectionRequiredException implements Exception {
  const TeamSelectionRequiredException([this.message = '必须选择团队']);

  final String message;

  @override
  String toString() => message;
}

class TeamContextService {
  TeamContextService({
    required AccountDetailLoader loadAccountDetail,
    required TeamChanger changeTeam,
    StorageService? storage,
  }) : _loadAccountDetail = loadAccountDetail,
       _changeTeam = changeTeam,
       _storage = storage ?? StorageService();

  final AccountDetailLoader _loadAccountDetail;
  final TeamChanger _changeTeam;
  final StorageService _storage;

  Future<List<Map<String, dynamic>>> loadTeams() async {
    final accountDetail = await _loadAccountDetail();
    if (accountDetail == null) {
      throw Exception('无法获取账户信息');
    }

    final teams = _readTeams(accountDetail);
    if (teams.isEmpty) {
      throw Exception('该账号没有关联任何团队');
    }
    return teams;
  }

  Future<TeamContext> initialize({TeamChooser? chooseTeam}) async {
    final accountDetail = await _loadAccountDetail();
    if (accountDetail == null) {
      throw Exception('无法获取账户信息');
    }

    final teams = _readTeams(accountDetail);
    if (teams.isEmpty) {
      throw Exception('该账号没有关联任何团队');
    }

    final savedTeamNo = await _storage.loadSelectedTeam();
    var teamChanged = false;
    Map<String, dynamic>? selectedTeam;

    if (teams.length == 1) {
      selectedTeam = teams.first;
      teamChanged = savedTeamNo != selectedTeam['teamNo'];
    } else if (savedTeamNo != null) {
      selectedTeam = _findTeam(teams, savedTeamNo);
      if (selectedTeam == null) {
        selectedTeam = await _chooseRequiredTeam(teams, chooseTeam);
        teamChanged = true;
      }
    } else {
      selectedTeam = await _chooseRequiredTeam(teams, chooseTeam);
      teamChanged = true;
    }

    return _activateTeam(
      selectedTeam,
      teamChanged: teamChanged,
      userName: _readUserName(accountDetail),
      skipIfCurrent: false,
    );
  }

  Future<Map<String, dynamic>> _chooseRequiredTeam(
    List<Map<String, dynamic>> teams,
    TeamChooser? chooseTeam,
  ) async {
    if (chooseTeam == null) {
      throw const TeamSelectionRequiredException();
    }

    final selectedTeam = await chooseTeam(teams);
    if (selectedTeam == null) {
      throw const TeamSelectionRequiredException();
    }

    return selectedTeam;
  }

  Future<TeamContext> switchTo(Map<String, dynamic> selectedTeam) async {
    return _activateTeam(
      selectedTeam,
      teamChanged: true,
      userName: await _storage.loadUserName(),
      skipIfCurrent: true,
    );
  }

  Future<TeamContext> _activateTeam(
    Map<String, dynamic> selectedTeam, {
    required bool teamChanged,
    required String? userName,
    required bool skipIfCurrent,
  }) async {
    final teamNo = selectedTeam['teamNo'] as String?;
    if (teamNo == null || teamNo.isEmpty) {
      throw Exception('团队信息不完整');
    }

    final currentTeamNo = await _storage.loadTeamNo();
    if (skipIfCurrent && teamNo == currentTeamNo) {
      return TeamContext(
        teamNo: teamNo,
        personNo: selectedTeam['personNo'] as String?,
        teamName: selectedTeam['teamName'] as String? ?? '未知团队',
        userName: userName,
        teamChanged: false,
      );
    }

    final changed = await _changeTeam(teamNo);
    if (!changed) {
      throw Exception('切换团队失败');
    }

    final personNo = selectedTeam['personNo'] as String?;
    final teamName = selectedTeam['teamName'] as String? ?? '未知团队';

    await _storage.saveTeamContext(
      teamNo: teamNo,
      personNo: personNo,
      teamName: teamName,
    );
    await _storage.saveSelectedTeam(teamNo);

    if (userName != null && userName.isNotEmpty) {
      await _storage.saveUserName(userName);
    }

    return TeamContext(
      teamNo: teamNo,
      personNo: personNo,
      teamName: teamName,
      userName: userName,
      teamChanged: teamChanged,
    );
  }

  List<Map<String, dynamic>> _readTeams(Map<String, dynamic> accountDetail) {
    final rawTeams = accountDetail['teamInfoList'];
    if (rawTeams is! List) return [];

    return rawTeams
        .whereType<Map>()
        .map((team) => Map<String, dynamic>.from(team))
        .toList();
  }

  Map<String, dynamic>? _findTeam(
    List<Map<String, dynamic>> teams,
    String teamNo,
  ) {
    for (final team in teams) {
      if (team['teamNo'] == teamNo) return team;
    }
    return null;
  }

  String? _readUserName(Map<String, dynamic> accountDetail) {
    final nickName = accountDetail['nickName'];
    return nickName is String && nickName.isNotEmpty ? nickName : null;
  }
}
