/// 登录页 WebView Cookie 中提取并规范化 token 的工具。
///
/// 与 WebView 集成路径（evaluateJavascript）解耦，提取/规范化逻辑可独立单测；
/// 真实 Cookie 集成路径无法在 Flutter 单测中覆盖，属真机测试缺口
/// （见 docs/操作记录.md）。
class LoginTokenExtractor {
  LoginTokenExtractor._();

  /// 从 document.cookie 格式的字符串中提取 www_token 的值。
  ///
  /// 找不到或值为空时返回 null；多个 cookie 之间以分号分隔。
  static String? extractWwwTokenFromCookieString(String cookieString) {
    for (final part in cookieString.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('www_token=')) {
        final value = trimmed.substring('www_token='.length).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// 规范化 WebView 返回值：过滤 null、字符串 'null'、空串与空白。
  ///
  /// evaluateJavascript 在无返回值时可能返回 null 或 'null' 字符串，
  /// 统一在此处过滤，避免保存空 token。
  static String? normalizeExtractedToken(Object? result) {
    final raw = result?.toString().trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }
    return raw;
  }
}
