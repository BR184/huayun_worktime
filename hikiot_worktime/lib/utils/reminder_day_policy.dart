import '../core/constants/constants.dart';
import '../services/storage_service.dart';
import 'date_helper.dart';

/// 打卡提醒日期策略。
///
/// 只判断某天是否应跳过工作提醒，不关心节假日数据如何存储。
class ReminderDayPolicy {
  ReminderDayPolicy({StorageService? storage})
    : _storage = storage ?? StorageService();

  final StorageService _storage;

  Future<bool> shouldSkipWorkReminder(DateTime date) async {
    final dateStr = DateHelper.formatDate(date);
    final dayType = await _storage.getDayType(dateStr);
    if (dayType == AppConstants.typeRestDay) return true;
    if (dayType == AppConstants.typeWorkday) return false;

    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
