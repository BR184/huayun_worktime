import 'work_time_calculator.dart';

class TargetProgressResult {
  const TargetProgressResult({
    required this.sortedTargetData,
    required this.highestAchievedTarget,
    required this.nextToAchieveTarget,
  });

  final List<Map<String, dynamic>> sortedTargetData;
  final int? highestAchievedTarget;
  final int? nextToAchieveTarget;
}

class TargetProgressHelper {
  TargetProgressHelper._();

  static const List<int> extendedTargets = [
    170,
    180,
    190,
    200,
    220,
    240,
    260,
    280,
    300,
  ];

  static TargetProgressResult buildDailyProgress({
    required double displayHours,
    required int baseTarget,
    required bool smartSort,
    required int? pinnedTarget,
  }) {
    final currentPercentage = displayHours / 8 * 100;
    final allTargets = _dailyTargets(baseTarget, currentPercentage);

    int? highestAchievedTarget;
    int? nextToAchieveTarget;
    for (final target in allTargets) {
      final targetHours = 8.0 * target / 100;
      if (displayHours >= targetHours) {
        highestAchievedTarget = target;
      } else {
        nextToAchieveTarget ??= target;
      }
    }

    final targetData = allTargets.map((target) {
      final targetHours = 8.0 * target / 100;
      return {
        'target': target,
        'targetHours': targetHours,
        'isCompleted': displayHours >= targetHours,
      };
    }).toList();

    final sortedTargetData = smartSort
        ? _sortDailyTargets(targetData)
        : _sortByTarget(targetData);
    movePinnedTargetToFront(sortedTargetData, pinnedTarget);

    return TargetProgressResult(
      sortedTargetData: sortedTargetData,
      highestAchievedTarget: highestAchievedTarget,
      nextToAchieveTarget: nextToAchieveTarget,
    );
  }

  static void movePinnedTargetToFront(
    List<Map<String, dynamic>> targetData,
    int? pinnedTarget,
  ) {
    if (pinnedTarget == null) return;

    final pinnedIndex = targetData.indexWhere(
      (data) => data['target'] == pinnedTarget,
    );
    if (pinnedIndex > 0) {
      final pinnedData = targetData.removeAt(pinnedIndex);
      targetData.insert(0, pinnedData);
    }
  }

  static List<int> _dailyTargets(int baseTarget, double currentPercentage) {
    final baseTargets = WorkTimeCalculator.generateTargetList(baseTarget);
    return currentPercentage >= 160
        ? [...baseTargets, ...extendedTargets]
        : baseTargets;
  }

  static List<Map<String, dynamic>> _sortDailyTargets(
    List<Map<String, dynamic>> targetData,
  ) {
    final completed = targetData
        .where((data) => data['isCompleted'] as bool)
        .toList();
    final incomplete = targetData
        .where((data) => !(data['isCompleted'] as bool))
        .toList();

    final highestAchieved = completed.isNotEmpty
        ? [completed.last]
        : <Map<String, dynamic>>[];
    final nextToAchieve = incomplete.isNotEmpty
        ? [incomplete.first]
        : <Map<String, dynamic>>[];
    final others = incomplete.skip(1).toList();
    final bothCompleted = completed.length > 1
        ? completed.sublist(0, completed.length - 1)
        : <Map<String, dynamic>>[];

    return [...highestAchieved, ...nextToAchieve, ...others, ...bothCompleted];
  }

  static List<Map<String, dynamic>> _sortByTarget(
    List<Map<String, dynamic>> targetData,
  ) {
    return List<Map<String, dynamic>>.from(targetData)
      ..sort((a, b) => (a['target'] as int).compareTo(b['target'] as int));
  }
}
