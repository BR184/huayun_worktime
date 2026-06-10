import '../services/storage_service.dart';
import '../core/constants/app_constants.dart';

/// 节假日工具类
/// 封装节假日更新的校验、API调用和UI反馈逻辑
class HolidayUtils {
  /// 同步海康原生的节假日/休息日状态到本地计划
  ///
  /// [dateKey] 格式为 yyyy-MM-dd
  /// [isRestDay] 海康 API 返回的是否为休息日
  /// [currentType] 内存中当前的类型
  /// [isManual] 是否为手动标记
  ///
  /// 返回新的类型，如果没有变化则返回 null
  static String? determineNativeType({
    required bool isRestDay,
    required String currentType,
    required bool isManual,
  }) {
    if (isManual) return null;

    final nativeType = isRestDay
        ? AppConstants.typeRestDay
        : AppConstants.typeWorkday;
    if (currentType != nativeType) {
      return nativeType;
    }
    return null;
  }

  /// 批量更新节假日计划并保存
  static Future<void> saveHolidayUpdate({
    required int year,
    required String dateKey,
    required String newType,
    required Map<String, String> holidayPlan,
    required StorageService storage,
  }) async {
    holidayPlan[dateKey] = newType;
    final plan = await storage.getHolidayPlan(year);
    plan[dateKey] = newType;
    await storage.saveHolidayPlan(year, plan);
  }
}
