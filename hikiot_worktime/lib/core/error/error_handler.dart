import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exceptions.dart';
import '../constants/storage_keys.dart';
import '../theme/app_colors.dart';
import '../../screens/login_screen.dart';

/// 统一错误处理器
/// 提供一致的错误处理和用户反馈机制
class ErrorHandler {
  ErrorHandler._();

  /// 处理异常并显示适当的用户反馈
  static void handle(
    BuildContext context,
    Object error, {
    String? fallbackMessage,
    VoidCallback? onRetry,
  }) {
    if (error is TokenExpiredException) {
      _handleTokenExpired(context);
    } else if (error is NetworkException) {
      _showErrorSnackBar(context, error.message, onRetry: onRetry);
    } else if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _handleTokenExpired(context);
      } else {
        _showErrorSnackBar(context, error.message, onRetry: onRetry);
      }
    } else if (error is ParseException) {
      _showErrorSnackBar(context, error.message);
    } else if (error is StorageException) {
      _showErrorSnackBar(context, error.message);
    } else {
      _showErrorSnackBar(
        context,
        fallbackMessage ?? '操作失败，请稍后重试',
        onRetry: onRetry,
      );
    }

    // 始终打印错误日志用于调试
    debugPrint('ErrorHandler: $error');
  }

  /// 处理Token过期
  static Future<void> _handleTokenExpired(BuildContext context) async {
    // 显示对话框
    final shouldRelogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
        title: const Text('登录已过期'),
        content: const Text('您的登录状态已失效，需要重新登录才能继续使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重新登录'),
          ),
        ],
      ),
    );

    if (shouldRelogin == true && context.mounted) {
      await _performLogout(context);
    }
  }

  /// 执行登出操作
  static Future<void> _performLogout(BuildContext context) async {
    try {
      // 清除Cookie
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();

      // 清除本地Token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.token);
      await prefs.remove(StorageKeys.personNo);
      await prefs.remove(StorageKeys.teamNo);

      // 跳转到登录页
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(forceLogout: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('登出失败: $e');
    }
  }

  /// 显示错误SnackBar
  static void _showErrorSnackBar(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: '重试',
                textColor: AppColors.onPrimary,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warningDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.infoDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 判断是否为Token过期异常（用于捕获字符串消息）
  static bool isTokenExpiredError(Object error) {
    if (error is TokenExpiredException) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('token') &&
        (errorStr.contains('expired') ||
            errorStr.contains('失效') ||
            errorStr.contains('过期'));
  }
}
