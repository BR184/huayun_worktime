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
      // 网络超时不是 token 失效
      expect(
        TokenExpiredService.isTokenExpiredError(NetworkException.timeout()),
        isFalse,
      );
      expect(
        TokenExpiredService.isTokenExpiredError(
          Exception('TimeoutException after 30s'),
        ),
        isFalse,
      );
    });

    test(
      'does not treat parse or ordinary business errors as token expired',
      () {
        expect(
          TokenExpiredService.isTokenExpiredError(
            const ParseException('数据解析失败'),
          ),
          isFalse,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(
            const ApiException('业务错误', code: '10001'),
          ),
          isFalse,
        );
        expect(
          TokenExpiredService.isTokenExpiredError(
            const ApiException('bad account', statusCode: 400),
          ),
          isFalse,
        );
      },
    );

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
      expect(
        TokenExpiredService.isTokenExpiredResponse({'statusCode': '401'}),
        isTrue,
      );
      expect(TokenExpiredService.isTokenExpiredResponse({'code': 0}), isFalse);
      expect(TokenExpiredService.isTokenExpiredResponse(null), isFalse);
    });

    test(
      'keeps 403 semantics aligned with api client (documented assumption)',
      () {
        // HTTP 403 暂按 token 失效处理，来自现有继承语义；
        // 仓库暂无正式契约证明其含义，若后续契约明确需同步调整
        // TokenExpiredService 与 HikiotApiClient 两处判定。
        expect(
          TokenExpiredService.isTokenExpiredError(
            const ApiException('未授权访问', statusCode: 403),
          ),
          isTrue,
        );
        expect(
          TokenExpiredService.isTokenExpiredResponse({'statusCode': 403}),
          isTrue,
        );
      },
    );

    test('detects structured exceptions with string code or int status', () {
      // ApiException.code 为字符串（业务 code 999999 统一转字符串）
      expect(
        TokenExpiredService.isTokenExpiredError(
          const ApiException('登录状态已失效', code: '999999'),
        ),
        isTrue,
      );
      // ApiException.statusCode 为 int（HTTP 401）
      expect(
        TokenExpiredService.isTokenExpiredError(
          const ApiException('未授权访问', statusCode: 401),
        ),
        isTrue,
      );
    });
  });
}
