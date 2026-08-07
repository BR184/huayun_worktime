import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/services/hikiot_api_client.dart';
import 'package:hikiot_worktime/services/token_expired_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HikiotApiClient account detail errors', () {
    test('throws token expired for unauthorized HTTP status', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      );

      expect(client.getAccountDetail(), throwsA(isA<TokenExpiredException>()));
    });

    test('throws API exception for non-zero business code', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 10001, 'message': 'bad account'}),
            200,
          );
        }),
      );

      expect(
        client.getAccountDetail(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', '10001')
              .having((error) => error.message, 'message', 'bad account'),
        ),
      );
    });
  });

  group('HikiotApiClient token expired and timeout handling', () {
    test(
      'throws token expired for forbidden HTTP status (403 semantics)',
      () async {
        // HTTP 403 按 token 失效处理：来自现有实现继承语义，
        // 仓库暂无正式契约证明其含义，与 TokenExpiredService 口径保持一致。
        final client = HikiotApiClient(
          token: 'token-1',
          httpClient: MockClient((request) async {
            return http.Response('forbidden', 403);
          }),
        );

        expect(
          client.getAccountDetail(),
          throwsA(isA<TokenExpiredException>()),
        );
      },
    );

    test('throws token expired for business code 999999', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          // 中文 message 需要按 UTF-8 字节构造 body
          return http.Response.bytes(
            utf8.encode(jsonEncode({'code': 999999, 'message': '登录状态已失效'})),
            200,
          );
        }),
      );

      expect(client.getAccountDetail(), throwsA(isA<TokenExpiredException>()));
    });

    test('converts request timeout to timeout network exception', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        requestTimeout: const Duration(milliseconds: 20),
        httpClient: MockClient((request) async {
          // 延迟需略大于超时阈值即可触发超时，避免拖慢测试
          await Future.delayed(const Duration(milliseconds: 60));
          return http.Response(jsonEncode({'code': 0}), 200);
        }),
      );

      // 超时是网络异常，不是 token 失效
      await expectLater(
        client.getAccountDetail(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            '请求超时，请稍后重试',
          ),
        ),
      );
      expect(
        TokenExpiredService.isTokenExpiredError(NetworkException.timeout()),
        isFalse,
      );
    });

    test('does not misjudge json parse error as token expired', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          return http.Response('not-json at all', 200);
        }),
      );

      await expectLater(
        client.getAccountDetail(),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('HikiotApiClient team and logout errors', () {
    test('does not convert team change API failure into false', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 20002, 'message': 'bad team'}),
            200,
          );
        }),
      );

      expect(
        client.changeTeam('team-1'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', '20002')
              .having((error) => error.message, 'message', 'bad team'),
        ),
      );
    });

    test('throws parse exception for invalid logout JSON', () async {
      final client = HikiotApiClient(
        token: 'token-1',
        httpClient: MockClient((request) async {
          return http.Response('not-json', 200);
        }),
      );

      expect(client.logout(), throwsA(isA<ParseException>()));
    });
  });
}
