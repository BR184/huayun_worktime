import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/constants/storage_keys.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
import 'package:hikiot_worktime/core/theme/app_theme.dart';
import 'package:hikiot_worktime/screens/settings_screen.dart';
import 'package:hikiot_worktime/services/hikiot_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// 设置页是长列表，放大测试视口让全部按钮可见（否则懒加载不会构建视口外内容）
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    HikiotApiClient? apiClient,
  }) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: SettingsScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();
  }

  /// 查找文本所在的具体按钮控件
  Finder buttonOf(String label) {
    return find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is ElevatedButton || widget is OutlinedButton,
      ),
    );
  }

  group('打卡提醒功能按钮', () {
    testWidgets('未开启任何提醒时"测试生效"禁用并显示辅助说明', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpSettings(tester);

      final testButton = tester.widget<ElevatedButton>(buttonOf('测试生效'));
      expect(testButton.onPressed, isNull);
      expect(find.textContaining('请先开启上班或下班提醒'), findsOneWidget);

      // "权限设置"始终可用
      final permissionButton = tester.widget<OutlinedButton>(buttonOf('权限设置'));
      expect(permissionButton.onPressed, isNotNull);
    });

    testWidgets('开启任一提醒后"测试生效"可用且隐藏辅助说明', (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.morningReminderEnabled: true,
        StorageKeys.morningReminderTime: '08:55',
      });
      await pumpSettings(tester);

      final testButton = tester.widget<ElevatedButton>(buttonOf('测试生效'));
      expect(testButton.onPressed, isNotNull);
      expect(find.textContaining('请先开启上班或下班提醒'), findsNothing);
    });

    testWidgets('开启下班提醒后"测试生效"同样可用', (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.eveningReminderEnabled: true,
        StorageKeys.eveningReminderTime: '21:00',
      });
      await pumpSettings(tester);

      final testButton = tester.widget<ElevatedButton>(buttonOf('测试生效'));
      expect(testButton.onPressed, isNotNull);
    });

    testWidgets('"权限设置"使用显式主色，边框/文字/图标与主题一致', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpSettings(tester);

      final permissionButton = tester.widget<OutlinedButton>(buttonOf('权限设置'));
      final style = permissionButton.style;
      expect(style?.foregroundColor?.resolve({}), AppColors.primary);
      expect(
        style?.side?.resolve({}),
        const BorderSide(color: AppColors.primary),
      );
    });

    testWidgets('关闭状态的开关圆圈使用可辨识颜色而非浅灰隐形', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpSettings(tester);

      // 取页面任意一个关闭态开关，解析主题关闭态颜色
      final switchContext = tester.element(find.byType(Switch).first);
      final switchTheme = Theme.of(switchContext).switchTheme;
      final thumbOff = switchTheme.thumbColor?.resolve({});
      final trackOff = switchTheme.trackColor?.resolve({});

      // 圆圈必须明显深于白色卡片背景（不能是 outline 浅色）
      expect(thumbOff, AppColors.textSecondary);
      expect(trackOff, AppColors.surfaceSunken);
      // 启用态未被覆盖：selected 分支返回 null 回退默认语义色
      expect(switchTheme.thumbColor?.resolve({WidgetState.selected}), isNull);
    });
  });

  group('切换团队 Token 失效', () {
    testWidgets('account/detail 抛 token 失效时进入统一失效对话框', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final apiClient = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          throw const TokenExpiredException();
        }),
      );
      await pumpSettings(tester, apiClient: apiClient);

      await tester.tap(find.text('切换团队'));
      await tester.pumpAndSettle();

      // 统一 Token 失效对话框，而非普通错误提示
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('登录状态已失效'), findsOneWidget);

      // 关闭对话框，不进入登出流程
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('普通 API 错误显示可恢复的错误提示', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final apiClient = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          // 中文 message 需要按 UTF-8 字节构造 body
          return http.Response.bytes(
            utf8.encode('{"code": 10001, "message": "服务繁忙"}'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await pumpSettings(tester, apiClient: apiClient);

      await tester.tap(find.text('切换团队'));
      await tester.pumpAndSettle();

      // 非 token 错误：普通 SnackBar，不弹失效对话框
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('切换团队失败'), findsOneWidget);
    });
  });
}
