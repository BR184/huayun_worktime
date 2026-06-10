import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/error/exceptions.dart';
import 'package:hikiot_worktime/services/hikiot_api_client.dart';
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
