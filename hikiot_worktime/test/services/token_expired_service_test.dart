import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/services/token_expired_service.dart';

void main() {
  group('TokenExpiredService', () {
    test(
      'detects token expired errors from structured exceptions and text',
      () {
        expect(
          TokenExpiredService.isTokenExpiredError(
            const TokenExpiredException(),
          ),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(Exception('登录状态已失效，请重新登录')),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(Exception('登录凭证已过期，请重新登录')),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(
            Exception('HTTP 401 Unauthorized'),
          ),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(
            Exception('business error: code = "999999"'),
          ),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(
            const ApiException('未授权访问', statusCode: 403),
          ),
          isTrue,
        );
      },
    );

    test('does not treat network errors as token expired', () {
      expect(
        TokenExpiredService.isTokenExpiredError(
          Exception('SocketException: failed host lookup'),
        ),
        isFalse,
      );
    });

    test('detects token expired API responses with int or string codes', () {
      expect(
        TokenExpiredService.isTokenExpiredResponse({'code': 999999}),
        isTrue,
      );
      expect(
        TokenExpiredService.isTokenExpiredResponse({'code': '999999'}),
        isTrue,
      );
      expect(
        TokenExpiredService.isTokenExpiredResponse({'statusCode': 401}),
        isTrue,
      );
      expect(
        TokenExpiredService.isTokenExpiredResponse({'status': '403'}),
        isTrue,
      );
      expect(TokenExpiredService.isTokenExpiredResponse({'code': 0}), isFalse);
      expect(TokenExpiredService.isTokenExpiredResponse(null), isFalse);
    });
  });
}
