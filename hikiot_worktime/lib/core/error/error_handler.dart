import 'dart:async';

import 'package:flutter/material.dart';
import 'exceptions.dart';
import '../theme/app_colors.dart';
import '../../services/token_expired_service.dart';

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
    if (TokenExpiredService.isTokenExpiredError(error)) {
      unawaited(TokenExpiredService.handleTokenExpired(context));
    } else if (error is NetworkException) {
      _showErrorSnackBar(context, error.message, onRetry: onRetry);
    } else if (error is ApiException) {
      _showErrorSnackBar(context, error.message, onRetry: onRetry);
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
    return TokenExpiredService.isTokenExpiredError(error);
  }
}
