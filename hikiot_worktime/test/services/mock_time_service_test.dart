import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/mock_time_service.dart';

void main() {
  group('MockPunchGenerator', () {
    test('随机打卡序列：首次 6~9 点、末次在模拟时间前 30 分钟内、有序', () {
      final mockNow = DateTime(2026, 8, 8, 18, 30);
      for (var i = 0; i < 50; i++) {
        final punches = MockPunchGenerator.randomPunches(mockNow);
        expect(punches.length, greaterThanOrEqualTo(2));
        expect(punches.length, lessThanOrEqualTo(6)); // 首末 + 最多 3 次中间 + 边界

        final first = punches.first;
        final last = punches.last;
        // 首次在 06:00~08:59
        expect(first.compareTo('06:00') >= 0, isTrue, reason: '首次 $first');
        expect(first.compareTo('09:00') < 0, isTrue, reason: '首次 $first');
        // 末次落在模拟时间前 30 分钟内（18:00~18:30）且晚于首次
        expect(last.compareTo('18:00') >= 0, isTrue, reason: '末次 $last');
        expect(last.compareTo('18:30') <= 0, isTrue, reason: '末次 $last');
        expect(last.compareTo(first) > 0, isTrue, reason: '首末 $first/$last');

        // 序列有序且不重复
        final sorted = [...punches]..sort();
        expect(punches, sorted);
      }
    });

    test('模拟时间接近首次打卡时末次仍有效', () {
      // 模拟时间 8:10：末次应在 [max(首次+1, 07:40), 08:10] 内
      final mockNow = DateTime(2026, 8, 8, 8, 10);
      for (var i = 0; i < 20; i++) {
        final punches = MockPunchGenerator.randomPunches(mockNow);
        expect(punches.length, greaterThanOrEqualTo(2));
        final first = punches.first;
        final last = punches.last;
        expect(last.compareTo('07:40') >= 0, isTrue, reason: '末次 $last');
        expect(last.compareTo('08:10') <= 0, isTrue, reason: '末次 $last');
        expect(last.compareTo(first) > 0, isTrue, reason: '首末 $first/$last');
      }
    });

    test('随机时间落在 8~23 点且日期在 0~6 天内（星期随机）', () {
      final today = DateTime.now();
      for (var i = 0; i < 30; i++) {
        final time = MockPunchGenerator.randomTime();
        expect(time.hour, inInclusiveRange(8, 23));
        final dayDiff = DateTime(
          time.year,
          time.month,
          time.day,
        ).difference(DateTime(today.year, today.month, today.day)).inDays;
        expect(dayDiff, inInclusiveRange(0, 6), reason: '日期偏移 $dayDiff');
      }
    });

    test('星期名映射正确', () {
      expect(MockPunchGenerator.weekdayName(DateTime(2026, 8, 8)), '周六');
      expect(MockPunchGenerator.weekdayName(DateTime(2026, 8, 7)), '周五');
      expect(MockPunchGenerator.weekdayName(DateTime(2026, 8, 10)), '周一');
    });
  });

  group('MockTimeService', () {
    tearDown(() => MockTimeService.instance.clear());

    test('未启用时返回真实时间，启用后返回模拟时间', () {
      final service = MockTimeService.instance;
      expect(service.isMocked, isFalse);

      final mock = DateTime(2026, 8, 8, 18, 0);
      service.setMock(mock);
      expect(service.isMocked, isTrue);
      // 模拟时钟与基准时间一致（±2 秒容差，因为随真实时间走秒）
      final now = service.now();
      expect(now.difference(mock).inSeconds.abs(), lessThanOrEqualTo(2));

      service.clear();
      expect(service.isMocked, isFalse);
    });

    test('打卡序列读写与清除', () {
      final service = MockTimeService.instance;
      service.setPunches(['08:05', '12:10', '13:20', '18:00']);
      expect(service.punches, ['08:05', '12:10', '13:20', '18:00']);

      service.clear();
      expect(service.punches, isEmpty);
    });
  });
}
