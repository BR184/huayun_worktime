import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'hikiot_api_client.dart';
import 'storage_service.dart';

typedef RemoteLogout = Future<void> Function(String token);
typedef ClearWebSession = Future<void> Function();

/// 会话服务：统一处理远程登出、WebView 会话清理和本地认证信息清理。
class SessionService {
  SessionService({
    StorageService? storage,
    RemoteLogout? remoteLogout,
    ClearWebSession? clearWebSession,
  }) : _storage = storage ?? StorageService(),
       _remoteLogout = remoteLogout ?? _defaultRemoteLogout,
       _clearWebSession = clearWebSession ?? clearHikiotCookies;

  final StorageService _storage;
  final RemoteLogout _remoteLogout;
  final ClearWebSession _clearWebSession;

  /// 完整退出登录：尽力通知服务端，然后清 WebView 和本地认证信息。
  Future<void> logout() async {
    final token = await _storage.loadToken();
    await clearRemoteAndWebSession(token);
    await _storage.clearAuthInfo();
  }

  /// 只清理服务端和 WebView 会话，不清本地 token。
  ///
  /// 调试 token 替换场景会先让旧 token 失效，再写入无效 token。
  Future<void> clearRemoteAndWebSession(String? token) async {
    final normalizedToken = _normalizeToken(token);
    if (_shouldCallRemoteLogout(normalizedToken)) {
      try {
        await _remoteLogout(normalizedToken!);
      } catch (e) {
        // 远程登出失败不阻断本地会话清理。
      }
    }

    await _clearWebSession();
  }

  static Future<void> _defaultRemoteLogout(String token) async {
    await HikiotApiClient(token: token).logout();
  }

  static Future<void> clearHikiotCookies() async {
    final cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
    try {
      await cookieManager.deleteCookies(url: WebUri('https://www.hikiot.com'));
      await cookieManager.deleteCookies(url: WebUri('https://hikiot.com'));
      await cookieManager.deleteCookies(url: WebUri('https://api.hikiot.com'));
    } catch (e) {
      // 忽略 URL 或平台 Cookie 清理异常，调用方仍会继续本地清理。
    }
  }

  bool _shouldCallRemoteLogout(String? token) {
    return token != null &&
        token.isNotEmpty &&
        !token.toUpperCase().startsWith('INVALID');
  }

  String? _normalizeToken(String? token) {
    final trimmed = token?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
