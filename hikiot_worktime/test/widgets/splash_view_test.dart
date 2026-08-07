import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_theme.dart';
import 'package:hikiot_worktime/main.dart';

void main() {
  testWidgets('renders the splash view without overflow on a compact phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashView()),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SplashView),
      matchesGoldenFile('goldens/splash_360x800.png'),
    );
  });
}
