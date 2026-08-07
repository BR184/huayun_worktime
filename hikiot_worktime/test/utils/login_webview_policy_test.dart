import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/login_webview_policy.dart';

void main() {
  group('LoginWebviewPolicy.shouldLoadInWebView', () {
    test('keeps hikiot domains inside the webview', () {
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://www.hikiot.com/portal/login'),
        ),
        isTrue,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://hikiot.com/portal/login'),
        ),
        isTrue,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://api.hikiot.com/api-website/v1/xxx'),
        ),
        isTrue,
      );
      // 任意子域也留在 WebView（登录后的中间跳转页）
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://oa.hikiot.com/sso'),
        ),
        isTrue,
      );
    });

    test('routes non-hikiot domains to the system browser', () {
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://weixin.qq.com/something'),
        ),
        isFalse,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://example.com'),
        ),
        isFalse,
      );
      // 形似 hikiot 的其他域名不允许
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://hikiot.com.evil.example/'),
        ),
        isFalse,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(
          Uri.parse('https://not-hikiot.com/'),
        ),
        isFalse,
      );
    });

    test('non-http schemes always go external', () {
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(Uri.parse('tel:10086')),
        isFalse,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(Uri.parse('mailto:a@b.com')),
        isFalse,
      );
      expect(
        LoginWebviewPolicy.shouldLoadInWebView(Uri.parse('intent://xxx')),
        isFalse,
      );
    });
  });

  group('LoginWebviewPolicy injection scripts', () {
    test('viewport fix script contains adaptive essentials', () {
      final script = LoginWebviewPolicy.buildViewportFixScript();
      expect(script, contains('viewport-fit=cover'));
      expect(script, contains('overflow-x: hidden'));
      expect(script, contains('box-sizing: border-box'));
    });

    test('cookie read script returns document.cookie', () {
      expect(
        LoginWebviewPolicy.buildCookieReadScript(),
        contains('document.cookie'),
      );
    });
  });
}
