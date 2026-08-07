import 'package:flutter/material.dart';
import '../core/constants/constants.dart';
import '../core/error/exceptions.dart';
import '../core/theme/theme.dart';
import 'session_service.dart';
import '../screens/login_screen.dart';

/// Token失效处理服务
/// 提供统一的Token失效检测和用户引导重新登录功能
class TokenExpiredService {
  static bool _isShowingDialog = false;

  /// 检查错误是否是Token失效导致的
  ///
  /// 判定口径（与 HikiotApiClient 保持一致）：
  /// - HTTP 401 与业务 code 999999 视为 token 失效（有实际观测依据）；
  /// - HTTP 403 暂按 token 失效处理，来自现有实现的继承语义，
  ///   仓库暂无正式接口契约证明其语义，若后续契约明确需同步调整
  ///   [hikiot_api_client.dart] 与此处两处判定；
  /// - 网络异常、JSON 解析异常、普通业务错误（如业务 code 10001）
  ///   一律不判定为 token 失效。
  static bool isTokenExpiredError(dynamic error) {
    if (error == null) return false;

    // 优先检查是否为定义的异常类型
    if (error is TokenExpiredException) return true;
    if (error is ApiException &&
        (_isExpiredCode(error.statusCode) || _isExpiredCode(error.code))) {
      return true;
    }

    // 字符串匹配兼容（面向历史遗留的字符串异常传播路径，尽力而为）
    final errorStr = error.toString();
    final lower = errorStr.toLowerCase();
    if (lower.contains('tokenexpiredexception')) return true;

    // 兼容旧的字符串判断，但收窄范围，避免网络错误误判
    return _containsExpiredStatus(lower) ||
        _containsExpiredBusinessCode(lower) ||
        errorStr.contains('登录状态已失效') ||
        errorStr.contains('登录凭证已过期') ||
        errorStr.contains('登录已过期') ||
        errorStr.contains('未授权访问');
  }

  /// 检查API响应是否表示Token失效
  static bool isTokenExpiredResponse(Map<String, dynamic>? response) {
    if (response == null) return false; // null可能是网络错误，不一定是Token失效

    return _isExpiredCode(response['code']) ||
        _isExpiredCode(response['statusCode']) ||
        _isExpiredCode(response['status']);
  }

  static bool _containsExpiredStatus(String lower) {
    if (lower.contains('unauthorized') || lower.contains('forbidden')) {
      return true;
    }
    return RegExp(r'(^|[^0-9])(401|403)([^0-9]|$)').hasMatch(lower);
  }

  static bool _containsExpiredBusinessCode(String lower) {
    return RegExp(r'\b"?code"?\s*[:=]\s*"?999999"?').hasMatch(lower);
  }

  static bool _isExpiredCode(Object? code) {
    final value = code is num ? code.toInt() : int.tryParse('$code'.trim());
    return value == AppConstants.apiCodeTokenExpired ||
        value == 401 ||
        value == 403;
  }

  /// 显示Token失效对话框并引导用户重新登录
  /// 返回 true 如果用户选择重新登录，false 如果用户取消
  static Future<bool> showTokenExpiredDialog(BuildContext context) async {
    // 页面销毁后不再弹框
    if (!context.mounted) return false;
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
      await SessionService().logout();

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
            child: Icon(
              Icons.lock_clock,
              color: AppColors.warningDark,
              size: 28,
            ),
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
