import 'package:flutter/foundation.dart';
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

  /// 完整退出登录：尽力通知服务端并清理 WebView，然后无条件清理本地认证。
  ///
  /// 三个环节相互隔离：远程登出失败、Cookie 清理失败都不会阻断本地清理；
  /// 失败只记录 debug 日志，不向上抛异常（除本地存储自身故障）。
  Future<void> logout() async {
    String? token;
    try {
      token = await _storage.loadToken();
    } catch (e) {
      // 读 token 失败不阻断后续清理
      debugPrint('登出：读取本地 token 失败，继续清理: $e');
    }

    try {
      await clearRemoteAndWebSession(token);
    } catch (e) {
      // 远程登出或 WebView 清理失败不阻断本地认证清理
      debugPrint('登出：远程/WebView 会话清理失败，继续本地清理: $e');
    } finally {
      // 本地认证清理必须无条件执行
      await _storage.clearAuthInfo();
    }
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
        // 远程登出失败不阻断本地会话清理，仅记录日志。
        debugPrint('登出：远程登出失败: $e');
      }
    }

    try {
      await _clearWebSession();
    } catch (e) {
      // WebView 会话清理失败不阻断本地认证清理，仅记录日志。
      debugPrint('登出：WebView 会话清理失败: $e');
    }
  }

  static Future<void> _defaultRemoteLogout(String token) async {
    await HikiotApiClient(token: token).logout();
  }

  static Future<void> clearHikiotCookies() async {
    try {
      final cookieManager = CookieManager.instance();
      // deleteAllCookies 可能抛平台异常，统一在下方兜底
      await cookieManager.deleteAllCookies();
      await cookieManager.deleteCookies(url: WebUri('https://www.hikiot.com'));
      await cookieManager.deleteCookies(url: WebUri('https://hikiot.com'));
      await cookieManager.deleteCookies(url: WebUri('https://api.hikiot.com'));
    } catch (e) {
      // Cookie API 失败不阻断后续本地认证清理，仅记录日志。
      debugPrint('登出：清理海康 Cookie 失败: $e');
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
