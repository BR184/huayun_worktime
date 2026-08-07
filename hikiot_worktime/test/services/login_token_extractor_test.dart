import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/utils/login_token_extractor.dart';

void main() {
  group('LoginTokenExtractor.extractWwwTokenFromCookieString', () {
    test('extracts www_token from full cookie string', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString(
          'theme=dark; www_token=abc123; session=xyz',
        ),
        'abc123',
      );
    });

    test('extracts www_token when it is the only cookie', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString('www_token=tok-1'),
        'tok-1',
      );
    });

    test('returns null when www_token is missing', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString(
          'theme=dark; session=xyz',
        ),
        isNull,
      );
    });

    test('returns null for empty cookie string', () {
      expect(LoginTokenExtractor.extractWwwTokenFromCookieString(''), isNull);
      expect(LoginTokenExtractor.extractWwwTokenFromCookieString('  '), isNull);
    });

    test('returns null when www_token value is empty', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString('www_token= ;a=1'),
        isNull,
      );
    });

    test('trims surrounding whitespace of the value', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString(
          'www_token=  tok-2  ; a=1',
        ),
        'tok-2',
      );
    });

    test('does not match prefix-like names such as www_token_extra', () {
      expect(
        LoginTokenExtractor.extractWwwTokenFromCookieString(
          'www_token_extra=1; a=2',
        ),
        isNull,
      );
    });
  });

  group('LoginTokenExtractor.normalizeExtractedToken', () {
    test('keeps non-empty token and preserves case', () {
      expect(LoginTokenExtractor.normalizeExtractedToken(' AbC123 '), 'AbC123');
    });

    test('filters null and missing values', () {
      expect(LoginTokenExtractor.normalizeExtractedToken(null), isNull);
      expect(LoginTokenExtractor.normalizeExtractedToken(''), isNull);
      expect(LoginTokenExtractor.normalizeExtractedToken('   '), isNull);
    });

    test('filters the string literal "null" regardless of case', () {
      expect(LoginTokenExtractor.normalizeExtractedToken('null'), isNull);
      expect(LoginTokenExtractor.normalizeExtractedToken('NULL'), isNull);
      expect(LoginTokenExtractor.normalizeExtractedToken(' Null '), isNull);
    });
  });

  group('LoginTokenExtractor integration-style flow', () {
    test('full pipeline: cookie string to normalized token', () {
      // 模拟 WebView document.cookie 的真实形态
      const raw = 'univerCity=1; www_token=  tok-9  ; other=2';
      final extracted = LoginTokenExtractor.extractWwwTokenFromCookieString(
        raw,
      );
      expect(LoginTokenExtractor.normalizeExtractedToken(extracted), 'tok-9');
    });

    test('full pipeline: missing token produces null and no save', () {
      final extracted = LoginTokenExtractor.extractWwwTokenFromCookieString(
        'univerCity=1',
      );
      expect(LoginTokenExtractor.normalizeExtractedToken(extracted), isNull);
    });
  });
}
