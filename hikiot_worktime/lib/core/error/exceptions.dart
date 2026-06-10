// 应用异常类定义
// 统一的异常类型，便于错误处理

/// 基础应用异常
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Token过期异常
class TokenExpiredException extends AppException {
  const TokenExpiredException([super.message = '登录状态已失效，请重新登录'])
    : super(code: 'TOKEN_EXPIRED');
}

/// 网络异常
class NetworkException extends AppException {
  const NetworkException([super.message = '网络连接失败，请检查网络设置'])
    : super(code: 'NETWORK_ERROR');

  factory NetworkException.timeout() => const NetworkException('请求超时，请稍后重试');

  factory NetworkException.noConnection() =>
      const NetworkException('无网络连接，请检查网络设置');

  factory NetworkException.fromError(dynamic error) =>
      NetworkException('网络请求失败: $error');
}

/// API响应异常
class ApiException extends AppException {
  final int? statusCode;

  const ApiException(
    super.message, {
    this.statusCode,
    super.code,
    super.originalError,
  });

  factory ApiException.fromResponse(int statusCode, String? message) {
    switch (statusCode) {
      case 401:
      case 403:
        return ApiException(
          message ?? '未授权访问',
          statusCode: statusCode,
          code: 'UNAUTHORIZED',
        );
      case 404:
        return ApiException(
          message ?? '请求的资源不存在',
          statusCode: statusCode,
          code: 'NOT_FOUND',
        );
      case 500:
        return ApiException(
          message ?? '服务器内部错误',
          statusCode: statusCode,
          code: 'SERVER_ERROR',
        );
      default:
        return ApiException(
          message ?? '请求失败 ($statusCode)',
          statusCode: statusCode,
        );
    }
  }
}

/// 数据解析异常
class ParseException extends AppException {
  const ParseException([super.message = '数据解析失败']) : super(code: 'PARSE_ERROR');

  factory ParseException.fromError(dynamic error) =>
      ParseException('数据解析失败: $error');
}

/// 存储异常
class StorageException extends AppException {
  const StorageException([super.message = '本地存储操作失败'])
    : super(code: 'STORAGE_ERROR');

  factory StorageException.readFailed(String key) =>
      StorageException('读取数据失败: $key');

  factory StorageException.writeFailed(String key) =>
      StorageException('保存数据失败: $key');
}

/// 验证异常
class ValidationException extends AppException {
  const ValidationException(super.message) : super(code: 'VALIDATION_ERROR');
}
