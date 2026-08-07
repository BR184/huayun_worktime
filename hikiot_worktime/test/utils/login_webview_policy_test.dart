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

  group('LoginWebviewPolicy.shouldTryExtractToken', () {
    test('skips extraction on login page loads', () {
      expect(
        LoginWebviewPolicy.shouldTryExtractToken(
          Uri.parse('https://www.hikiot.com/portal/login'),
        ),
        isFalse,
      );
      expect(
        LoginWebviewPolicy.shouldTryExtractToken(
          Uri.parse('https://www.hikiot.com/portal/login#/sso'),
        ),
        isFalse,
      );
    });

    test('extracts after login or on any non-login page', () {
      expect(
        LoginWebviewPolicy.shouldTryExtractToken(
          Uri.parse('https://www.hikiot.com/portal/main'),
        ),
        isTrue,
      );
      // hash 路由仍带 /login 前缀时无法区分，交给 Cookie 探测兜底
      expect(LoginWebviewPolicy.shouldTryExtractToken(null), isFalse);
    });
  });
}
