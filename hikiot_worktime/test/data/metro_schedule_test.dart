import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/data/metro_schedule.dart';

void main() {
  group('汉峪金谷地铁时刻表', () {
    test('方向① 平峰段与官方实测锚点逐班一致（14:02~14:32）', () {
      final times = HanyuJinguMetro.lineWest.times();
      final anchors = [
        14 * 60 + 2,
        14 * 60 + 8,
        14 * 60 + 14,
        14 * 60 + 20,
        14 * 60 + 26,
        14 * 60 + 32,
      ];
      for (final anchor in anchors) {
        expect(
          times,
          contains(anchor),
          reason: '缺少班次 ${anchor ~/ 60}:${anchor % 60}',
        );
      }
    });

    test('方向① 首末班与班次数', () {
      final times = HanyuJinguMetro.lineWest.times();
      expect(times.first, 6 * 60 + 2);
      expect(times.last, 22 * 60 + 51);
      // 官方 180 班；模型过渡允许 ±1-2 分钟差异，班次数量允许少量偏差
      expect(times.length, inInclusiveRange(170, 190));
    });

    test('方向② 末班 23:25，方向③ 末班 19:58（20:00 后停运）', () {
      final east = HanyuJinguMetro.lineEastBranch.times();
      expect(east.first, 6 * 60 + 11);
      expect(east.last, 23 * 60 + 25);

      final through = HanyuJinguMetro.lineEastThrough.times();
      expect(through.first, 6 * 60 + 4);
      expect(through.last, 19 * 60 + 58);
      expect(through.where((t) => t >= 20 * 60), isEmpty);
    });

    test('nextTrainAfter 返回最近班次', () {
      final west = HanyuJinguMetro.lineWest;
      expect(west.nextTrainAfter(14 * 60 + 3), 14 * 60 + 8);
      expect(west.nextTrainAfter(14 * 60 + 8), 14 * 60 + 8);
      expect(west.nextTrainAfter(23 * 60), isNull); // 已收班
    });

    test('20:00 时方向①仍有车，方向③（8号线）已停运', () {
      // 方向① 末班 22:51，20:00 下班仍有 20:10 班次
      expect(
        HanyuJinguMetro.lineWest.nextTrainAfter(20 * 60 + 7),
        20 * 60 + 10,
      );
      // 方向③ 末班 19:58，20:00 后无车（用户提供的数据：贯通停运）
      expect(
        HanyuJinguMetro.lineEastThrough.nextTrainAfter(20 * 60 + 7),
        isNull,
      );
    });
  });
}
