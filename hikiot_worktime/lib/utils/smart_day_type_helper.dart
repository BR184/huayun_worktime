import 'package:intl/intl.dart';
import '../core/constants/constants.dart';

/// 智能日期类型工具类
/// 
/// 职责单一：处理日期类型的智能识别逻辑
/// - 工作日无工时 → 请假
/// - 非工作日有工时 → 加班日
class SmartDayTypeHelper {
  SmartDayTypeHelper._();

  /// 判断类型是否为休息日类型（休息、非工作日、节假日）
  static bool isRestDayType(String? type) {
    return type == '休息' || 
           type == AppConstants.typeRestDay || 
           type == '节假日';
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
  /// 
  /// 返回推断后的类型，如果不需要修改则返回 null
  static String? inferDayType({
    required String? currentType,
    required num hours,
    required String dateStr,
    bool isManual = false,
  }) {
    // 手动标记不做修改
    if (isManual) return null;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 非工作日有工时 → 加班日
    if (hours > 0 && isRestDayType(currentType)) {
      return AppConstants.typeOvertime;
    }

    // 工作日无工时且是过去日期 → 请假
    if (hours == 0 && isWorkdayType(currentType) && dateStr.compareTo(today) < 0) {
      return AppConstants.typeLeave;
    }

    return null;
  }

  /// 批量应用智能日期类型
  /// 
  /// 遍历月度数据，对所有非手动标记的日期应用智能类型逻辑
  /// 直接修改传入的 Map
  static void applyToMonthlyData(Map<String, Map<String, dynamic>> monthlyData) {
    monthlyData.forEach((dateStr, data) {
      final isManual = data['isManual'] == true;
      final hours = (data['hours'] ?? 0.0) as num;
      final currentType = data['type'] as String?;

      final newType = inferDayType(
        currentType: currentType,
        hours: hours,
        dateStr: dateStr,
        isManual: isManual,
      );

      if (newType != null) {
        data['type'] = newType;
      }
    });
  }
}
