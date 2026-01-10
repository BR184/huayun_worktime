import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants/constants.dart';
import '../core/error/exceptions.dart';
import '../core/theme/theme.dart';
import 'storage_service.dart';
import '../screens/login_screen.dart';

/// Token失效处理服务
/// 提供统一的Token失效检测和用户引导重新登录功能
class TokenExpiredService {
  static bool _isShowingDialog = false;

  /// 检查错误是否是Token失效导致的
  static bool isTokenExpiredError(dynamic error) {
    if (error == null) return false;

    // 优先检查是否为定义的异常类型
    if (error is TokenExpiredException) return true;

    // 字符串匹配兼容
    final errorStr = error.toString();
    if (errorStr.contains('TokenExpiredException')) return true;

    // 兼容旧的字符串判断，但收窄范围，避免网络错误误判
    final lower = errorStr.toLowerCase();
    return lower.contains('code: ${AppConstants.apiCodeTokenExpired}') ||
        lower.contains('status code: 401') ||
        lower.contains('status code: 403') ||
        lower.contains('登录状态已失效');
  }

  /// 检查API响应是否表示Token失效
  static bool isTokenExpiredResponse(Map<String, dynamic>? response) {
    if (response == null) return false; // null可能是网络错误，不一定是Token失效

    final code = response['code'];
    return code == AppConstants.apiCodeTokenExpired || code == 401 || code == 403;
  }

  /// 显示Token失效对话框并引导用户重新登录
  /// 返回 true 如果用户选择重新登录，false 如果用户取消
  static Future<bool> showTokenExpiredDialog(BuildContext context) async {
    // 防止重复弹出
    if (_isShowingDialog) return false;
    _isShowingDialog = true;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // 不允许点击外部关闭
        builder: (context) => _TokenExpiredDialog(),
      );
      return result ?? false;
    } finally {
      _isShowingDialog = false;
    }
  }

  /// 执行退出登录并跳转到登录页面
  /// 复用设置页面的退出登录逻辑
  static Future<void> performLogoutAndNavigate(BuildContext context) async {
    try {
      // 获取 token 用于调用登出接口
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('hikiot_token');

      // 调用官方登出 API（可能失败，但不影响后续流程）
      if (token != null && token.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('https://api.hikiot.com/api-website/v1/logout'),
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Authorization': 'Bearer $token',
              'Authorization-other': 'Bearer $token',
              'Origin': 'https://www.hikiot.com',
              'Referer': 'https://www.hikiot.com/',
              'STN-PhoneType': 'Android 10',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36',
              'deviceid': 'unHotjaMGfLZCj0N',
              'devicename': 'Android 10',
              'terminal': '2',
            },
          );
          print('登出 API 调用成功');
        } catch (e) {
          print('登出 API 调用失败: $e');
        }
      }

      // 清除 WebView cookies（关键！否则自动登录会生效）
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
      try {
        await cookieManager.deleteCookies(url: WebUri('https://www.hikiot.com'));
        await cookieManager.deleteCookies(url: WebUri('https://hikiot.com'));
        await cookieManager.deleteCookies(url: WebUri('https://api.hikiot.com'));
      } catch (e) {
        // 忽略URL解析错误
      }

      // 使用 StorageService 清除认证信息 (保留用户设置)
      final storage = StorageService();
      await storage.clearAuthInfo();

      // 跳转到登录页（使用 forceLogout 确保 WebView 也清除 cookies）
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(forceLogout: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('退出登录过程中出错: $e');
      // 即使出错也尝试跳转到登录页
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(forceLogout: true),
          ),
          (route) => false,
        );
      }
    }
  }

  /// 处理Token失效：显示对话框并在用户确认后执行登出
  static Future<void> handleTokenExpired(BuildContext context) async {
    final shouldLogout = await showTokenExpiredDialog(context);
    if (shouldLogout && context.mounted) {
      await performLogoutAndNavigate(context);
    }
  }
}

/// Token失效对话框
class _TokenExpiredDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimens.borderRadiusLg),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: AppDimens.borderRadiusMd,
            ),
            child: Icon(Icons.lock_clock, color: AppColors.warningDark, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '登录状态已失效',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '您的登录凭证已过期，无法获取考勤数据。',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: AppDimens.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请重新登录以继续使用应用',
                    style: TextStyle(fontSize: 13, color: AppColors.infoDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '可能的原因：',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildReasonItem('• 登录凭证已超时（通常7天后失效）'),
          _buildReasonItem('• 在其他设备上登录了相同账号'),
          _buildReasonItem('• 账号密码已被修改'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('稍后再说', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('重新登录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: AppDimens.borderRadiusMd,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
