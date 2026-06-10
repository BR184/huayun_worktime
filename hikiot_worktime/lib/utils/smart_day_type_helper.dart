import '../core/constants/constants.dart';
import 'date_helper.dart';

enum DayDataSourceStatus { unknown, apiConfirmed }

/// 智能日期类型工具类
///
/// 职责单一：处理日期类型的智能识别逻辑
/// - 工作日无工时 → 请假
/// - 非工作日有工时 → 加班日
class SmartDayTypeHelper {
  SmartDayTypeHelper._();

  static const String dataSourceStatusKey = 'dataSourceStatus';
  static const String dataSourceStatusUnknown = 'unknown';
  static const String dataSourceStatusApiConfirmed = 'apiConfirmed';

  static DayDataSourceStatus parseDataSourceStatus(Object? value) {
    if (value is DayDataSourceStatus) return value;
    if (value == dataSourceStatusApiConfirmed) {
      return DayDataSourceStatus.apiConfirmed;
    }
    return DayDataSourceStatus.unknown;
  }

  static String serializeDataSourceStatus(DayDataSourceStatus status) {
    return switch (status) {
      DayDataSourceStatus.apiConfirmed => dataSourceStatusApiConfirmed,
      DayDataSourceStatus.unknown => dataSourceStatusUnknown,
    };
  }

  /// 判断类型是否为休息日类型（休息、非工作日、节假日）
  static bool isRestDayType(String? type) {
    return type == '休息' || type == AppConstants.typeRestDay || type == '节假日';
  }

  /// 判断类型是否为工作日类型
  static bool isWorkdayType(String? type) {
    return type == AppConstants.typeWorkday;
  }

  /// 智能推断日期类型
  ///
  /// [currentType] 当前类型
  /// [hours] 当日工时
  /// [dateStr] 日期字符串 (yyyy-MM-dd)
  /// [isManual] 是否手动标记
  /// [hasCheckIn] 是否有打卡记录 (用于识别只打了一次卡也算加班的情况)
  /// [dataSourceStatus] 是否已由 API 成功确认该日数据
  ///
  /// 返回推断后的类型，如果不需要修改则返回 null
  static String? inferDayType({
    required String? currentType,
    required num hours,
    required String dateStr,
    bool isManual = false,
    bool hasCheckIn = false,
    DayDataSourceStatus dataSourceStatus = DayDataSourceStatus.unknown,
    DateTime? currentWorkDate,
  }) {
    // 手动标记不做修改
    if (isManual) return null;

    final today = DateHelper.formatDate(
      currentWorkDate ?? DateHelper.getWorkDate(),
    );

    // 非工作日有工时 OR 有打卡记录 → 加班日
    // 即使只打了一次卡(工时为0),只要是休息日且去打卡了,也应视为加班
    if ((hours > 0 || hasCheckIn) && isRestDayType(currentType)) {
      return AppConstants.typeOvertime;
    }

    // 工作日无工时且是过去日期 → 请假
    // 注意: 这里不考虑 hasCheckIn, 因为工作日只有上班卡没下班卡算异常缺卡, 不算完全的"工作", 但也不算"请假"
    //      通常工作日缺卡会显示异常, 由用户手动处理或补卡. 此处"请假"主要针对完全未打卡的情况.
    if (dataSourceStatus == DayDataSourceStatus.apiConfirmed &&
        hours == 0 &&
        !hasCheckIn &&
        isWorkdayType(currentType) &&
        dateStr.compareTo(today) < 0) {
      return AppConstants.typeLeave;
    }

    return null;
  }

  /// 批量应用智能日期类型
  ///
  /// 遍历月度数据，对所有非手动标记的日期应用智能类型逻辑
  /// 直接修改传入的 Map
  static void applyToMonthlyData(
    Map<String, Map<String, dynamic>> monthlyData,
  ) {
    monthlyData.forEach((dateStr, data) {
      final isManual = data['isManual'] == true;
      final hours = (data['hours'] ?? 0.0) as num;
      final currentType = data['type'] as String?;
      final checkIn = data['checkIn'] as String?;
      final hasCheckIn =
          checkIn != null && checkIn.isNotEmpty && checkIn != '-';
      final dataSourceStatus = parseDataSourceStatus(data[dataSourceStatusKey]);

      final newType = inferDayType(
        currentType: currentType,
        hours: hours,
        dateStr: dateStr,
        isManual: isManual,
        hasCheckIn: hasCheckIn,
        dataSourceStatus: dataSourceStatus,
      );

      if (newType != null) {
        data['type'] = newType;
      }
    });
  }
}
