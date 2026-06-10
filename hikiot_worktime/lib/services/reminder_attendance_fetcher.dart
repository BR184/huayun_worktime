import 'package:intl/intl.dart';

import '../core/error/exceptions.dart';
import 'hikiot_api_client.dart';
import 'storage_service.dart';

typedef DailyAttendanceLoader =
    Future<Map<String, dynamic>?> Function(
      String token,
      String date,
      String personNo,
    );

class ReminderAttendanceResult {
  final Map<String, dynamic>? data;
  final bool tokenExpired;

  const ReminderAttendanceResult({
    required this.data,
    required this.tokenExpired,
  });
}

class ReminderAttendanceFetcher {
  final StorageService storage;
  final DateTime Function() now;
  final DailyAttendanceLoader dailyAttendanceLoader;

  ReminderAttendanceFetcher({
    StorageService? storage,
    DateTime Function()? now,
    DailyAttendanceLoader? dailyAttendanceLoader,
  }) : storage = storage ?? StorageService(),
       now = now ?? DateTime.now,
       dailyAttendanceLoader = dailyAttendanceLoader ?? _loadWithApiClient;

  Future<ReminderAttendanceResult> fetchToday() async {
    final token = await storage.loadToken();
    final personNo = await storage.loadPersonNo();

    if (token == null || token.isEmpty) {
      return const ReminderAttendanceResult(data: null, tokenExpired: true);
    }

    if (personNo == null || personNo.isEmpty) {
      return const ReminderAttendanceResult(data: null, tokenExpired: false);
    }

    final date = DateFormat('yyyy-MM-dd').format(now());

    try {
      final data = await dailyAttendanceLoader(token, date, personNo);
      return ReminderAttendanceResult(data: data, tokenExpired: false);
    } on TokenExpiredException {
      return const ReminderAttendanceResult(data: null, tokenExpired: true);
    } catch (_) {
      return const ReminderAttendanceResult(data: null, tokenExpired: false);
    }
  }

  static Future<Map<String, dynamic>?> _loadWithApiClient(
    String token,
    String date,
    String personNo,
  ) {
    return HikiotApiClient(token: token).getDailyAttendance(date, personNo);
  }
}
