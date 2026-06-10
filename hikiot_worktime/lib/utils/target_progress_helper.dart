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

  static TargetProgressResult buildMonthlyProgress({
    required double adjustedTotalHours,
    required double baseHours,
    required double avgHoursPerDay,
    required int remainingWorkDays,
    required int baseTarget,
    required bool smartSort,
    required int? pinnedTarget,
  }) {
    final currentPercentage = baseHours > 0
        ? adjustedTotalHours / baseHours * 100
        : 0.0;
    final targets = _targetsForPercentage(baseTarget, currentPercentage);
    final targetData = targets.map((target) {
      final targetHours = baseHours * target / 100;
      final isCompleted = currentPercentage >= target;
      final gapHours = targetHours - adjustedTotalHours;
      final dailyNeed = remainingWorkDays > 0
          ? gapHours / remainingWorkDays
          : 0.0;
      final targetAvgHours = 8.0 * target / 100;
      final avgProgress = targetAvgHours > 0
          ? avgHoursPerDay / targetAvgHours
          : 0.0;

      return {
        'target': target,
        'targetHours': targetHours,
        'isCompleted': isCompleted,
        'avgCompleted': avgProgress >= 1.0,
        'gapHours': gapHours,
        'dailyNeed': dailyNeed,
        'avgHoursPerDay': avgHoursPerDay,
        'targetAvgHours': targetAvgHours,
        'avgProgress': avgProgress,
      };
    }).toList();

    final sortedResult = smartSort
        ? _sortMonthlySmart(targetData)
        : _sortMonthlyNormal(targetData);
    movePinnedTargetToFront(sortedResult.sortedTargetData, pinnedTarget);

    return sortedResult;
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
    return _targetsForPercentage(baseTarget, currentPercentage);
  }

  static List<int> _targetsForPercentage(
    int baseTarget,
    double currentPercentage,
  ) {
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

  static TargetProgressResult _sortMonthlySmart(
    List<Map<String, dynamic>> targetData,
  ) {
    final bothCompleted = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];

    for (final data in targetData) {
      final avgCompleted = data['avgCompleted'] as bool;
      final isCompleted = data['isCompleted'] as bool;
      if (avgCompleted && isCompleted) {
        bothCompleted.add(data);
      } else {
        others.add(data);
      }
    }

    bothCompleted.sort(_compareByTarget);
    others.sort(_compareByTarget);

    Map<String, dynamic>? highestAchievedData;
    Map<String, dynamic>? nextToAchieveData;
    for (var i = others.length - 1; i >= 0; i--) {
      if (others[i]['avgCompleted'] as bool) {
        highestAchievedData = others[i];
        break;
      }
    }
    for (final data in others) {
      if (!(data['avgCompleted'] as bool)) {
        nextToAchieveData = data;
        break;
      }
    }

    if (highestAchievedData != null) {
      others.remove(highestAchievedData);
    }
    if (nextToAchieveData != null) {
      others.remove(nextToAchieveData);
    }

    return TargetProgressResult(
      sortedTargetData: [
        ?highestAchievedData,
        ?nextToAchieveData,
        ...others,
        ...bothCompleted,
      ],
      highestAchievedTarget: highestAchievedData?['target'] as int?,
      nextToAchieveTarget: nextToAchieveData?['target'] as int?,
    );
  }

  static TargetProgressResult _sortMonthlyNormal(
    List<Map<String, dynamic>> targetData,
  ) {
    final sortedTargetData = _sortByTarget(targetData);
    int? highestAchievedTarget;
    int? nextToAchieveTarget;

    for (var i = sortedTargetData.length - 1; i >= 0; i--) {
      if (sortedTargetData[i]['avgCompleted'] as bool) {
        highestAchievedTarget = sortedTargetData[i]['target'] as int;
        break;
      }
    }
    for (final data in sortedTargetData) {
      if (!(data['avgCompleted'] as bool)) {
        nextToAchieveTarget = data['target'] as int;
        break;
      }
    }

    return TargetProgressResult(
      sortedTargetData: sortedTargetData,
      highestAchievedTarget: highestAchievedTarget,
      nextToAchieveTarget: nextToAchieveTarget,
    );
  }

  static List<Map<String, dynamic>> _sortByTarget(
    List<Map<String, dynamic>> targetData,
  ) {
    return List<Map<String, dynamic>>.from(targetData)..sort(_compareByTarget);
  }

  static int _compareByTarget(Map<String, dynamic> a, Map<String, dynamic> b) {
    return (a['target'] as int).compareTo(b['target'] as int);
  }
}
