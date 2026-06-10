import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class DeviceBrandService {
  DeviceBrandService({MethodChannel? channel, bool? isAndroid})
    : _channel =
          channel ?? const MethodChannel('com.hikiot.worktime/device_info'),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _isAndroid;

  Future<String> loadBrand() async {
    if (!_isAndroid) return 'other';

    try {
      final brand = await _channel.invokeMethod<String>('getBrand');
      final normalized = brand?.trim().toLowerCase();
      return normalized == null || normalized.isEmpty ? 'other' : normalized;
    } catch (_) {
      return 'other';
    }
  }
}
