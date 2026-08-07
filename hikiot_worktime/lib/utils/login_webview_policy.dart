/// 登录页 WebView 的导航与页面适配策略。
///
/// 登录依赖 Hikiot 网页验证（账号密码/短信验证码后读取 www_token Cookie），
/// 必须把 Hikiot 域名内的页面留在 WebView 内加载；其余外链（忘记密码、
/// 帮助、第三方登录等）交给系统浏览器，避免用户被带离登录流程。
/// 判定逻辑为纯函数，可独立单测。
class LoginWebviewPolicy {
  LoginWebviewPolicy._();

  /// 允许留在 WebView 内加载的域名（含所有子域）。
  static const List<String> _allowedHosts = ['hikiot.com'];

  /// 是否允许在 WebView 内加载该 URL。
  ///
  /// 判定规则：https/http 且域名为 hikiot.com 或其子域时放行；
  /// 其余协议（tel:/mailto:/intent: 等）一律视为外链。
  static bool shouldLoadInWebView(Uri url) {
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    final host = url.host.toLowerCase();
    return _allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  /// 生成登录页移动端适配注入脚本（onLoadStop 时注入）。
  ///
  /// 确保 viewport 正确并做溢出兜底，避免页面显示不全；
  /// 已包含刘海屏安全区（viewport-fit=cover）。
  static String buildViewportFixScript() {
    return '''
      (function() {
        // 确保viewport meta标签正确，设置初始缩放与刘海屏安全区
        var viewport = document.querySelector('meta[name=viewport]');
        if (viewport) {
          viewport.setAttribute('content', 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover');
        } else {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover';
          document.getElementsByTagName('head')[0].appendChild(meta);
        }

        // 添加CSS修复样式，确保内容不超出屏幕
        var style = document.createElement('style');
        style.textContent = `
          * {
            box-sizing: border-box !important;
          }
          html, body {
            margin: 0 !important;
            padding: 0 !important;
            overflow-x: hidden !important;
            width: 100% !important;
            max-width: 100vw !important;
          }
          body > * {
            max-width: 100% !important;
          }
          .container, [class*="container"] {
            max-width: 100% !important;
            padding-left: 10px !important;
            padding-right: 10px !important;
          }
        `;
        document.head.appendChild(style);

        // 延迟100ms后重新调整
        setTimeout(function() {
          window.scrollTo(0, 0);
          // 尝试让页面重新布局
          document.body.style.width = '100%';
        }, 100);
      })();
    ''';
  }

  /// 生成读取 document.cookie 的注入脚本。
  ///
  /// 返回完整 Cookie 字符串，在 Dart 侧用 [LoginTokenExtractor] 解析。
  static String buildCookieReadScript() {
    return '''
      (function() {
        return document.cookie;
      })();
    ''';
  }

  /// 整页加载（onLoadStop）后是否尝试提取 token。
  ///
  /// 登录页本身（URL 含 /login）不提取；登录成功、团队选择、
  /// 软件页面等非登录页加载完成后才尝试。
  static bool shouldTryExtractToken(Uri? url) {
    if (url == null) return false;
    return !url.toString().contains('/login');
  }
}
