import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/storage_keys.dart';
import 'package:hikiot_worktime/widgets/best_clock_out_setup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('初始化弹窗选择自由方式并保存', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final future = BestClockOutSetupDialog.show(
      tester.element(find.byType(Scaffold)),
    );
    await tester.pumpAndSettle();

    // 默认自由，直接确定
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.commuteMode), 'free');
  });

  testWidgets('选择地铁并选方向后保存', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final future = BestClockOutSetupDialog.show(
      tester.element(find.byType(Scaffold)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('地铁'));
    await tester.pumpAndSettle();
    // 出现方向选择，选第二个方向（彭家庄）
    await tester.tap(find.textContaining('彭家庄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.commuteMode), 'metro');
    expect(prefs.getInt(StorageKeys.commuteMetroDirection), 1);
  });
}
