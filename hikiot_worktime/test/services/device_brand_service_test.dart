import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/services/device_brand_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceBrandService', () {
    test('normalizes Android brand from platform channel', () async {
      const channel = MethodChannel('test_device_brand');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getBrand');
            return 'Xiaomi';
          });

      final service = DeviceBrandService(channel: channel, isAndroid: true);

      expect(await service.loadBrand(), 'xiaomi');
    });

    test('falls back to other when platform channel fails', () async {
      const channel = MethodChannel('test_device_brand_fails');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      final service = DeviceBrandService(channel: channel, isAndroid: true);

      expect(await service.loadBrand(), 'other');
    });

    test('returns other outside Android', () async {
      final service = DeviceBrandService(isAndroid: false);

      expect(await service.loadBrand(), 'other');
    });
  });
}
