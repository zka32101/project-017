import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/services/revenue_cat_oauth_service.dart';

import '../test_utils/fakes.dart';

class _FixedWebAuthLauncher implements WebAuthLauncher {
  _FixedWebAuthLauncher(this.result);

  /// 呼び出し時、実際に構築された認可URLを検証できるよう保持しておく。
  String? capturedAuthUrl;
  final String Function(Uri authUrl) result;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    capturedAuthUrl = url;
    expect(callbackUrlScheme, 'ririkan');
    return result(Uri.parse(url));
  }
}

void main() {
  group('RevenueCatOAuthService.isConnected / disconnect', () {
    test('初期状態は未接続', () async {
      final service = RevenueCatOAuthService(
        secureStorageService: FakeSecureStorageService(),
      );
      expect(await service.isConnected(), isFalse);
    });

    test('connect成功後は接続済みになり、disconnectで未接続に戻る', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.revenuecat.com/oauth2/token');
        expect(request.bodyFields['grant_type'], 'authorization_code');
        expect(request.bodyFields['code'], 'auth-code-123');
        expect(request.bodyFields['code_verifier'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'access_token': 'at1',
            'refresh_token': 'rt1',
            'expires_in': 3600,
          }),
          200,
        );
      });
      final launcher = _FixedWebAuthLauncher((authUrl) {
        final state = authUrl.queryParameters['state']!;
        return 'ririkan://revenuecat-oauth-callback?code=auth-code-123&state=$state';
      });
      final service = RevenueCatOAuthService(
        secureStorageService: storage,
        webAuthLauncher: launcher,
        httpClient: client,
      );

      await service.connect(clientId: 'cid', clientSecret: 'csecret');

      expect(await service.isConnected(), isTrue);
      expect(launcher.capturedAuthUrl, contains('response_type=code'));
      expect(launcher.capturedAuthUrl, contains('client_id=cid'));
      expect(launcher.capturedAuthUrl, contains('code_challenge_method=S256'));

      await service.disconnect();
      expect(await service.isConnected(), isFalse);
    });

    test('stateが一致しなければ例外を投げ、トークンは保存されない', () async {
      final storage = FakeSecureStorageService();
      final client = MockClient((request) async {
        fail('state不一致時はトークンエンドポイントを呼ばないはず');
      });
      final launcher = _FixedWebAuthLauncher(
        (authUrl) => 'ririkan://revenuecat-oauth-callback?code=c&state=WRONG',
      );
      final service = RevenueCatOAuthService(
        secureStorageService: storage,
        webAuthLauncher: launcher,
        httpClient: client,
      );

      await expectLater(
        service.connect(clientId: 'cid', clientSecret: 'csecret'),
        throwsA(isA<RevenueCatAuthException>()),
      );
      expect(await service.isConnected(), isFalse);
    });

    test('RevenueCat側がerrorパラメータ付きで返すと例外を投げる', () async {
      final storage = FakeSecureStorageService();
      final launcher = _FixedWebAuthLauncher(
        (authUrl) => 'ririkan://revenuecat-oauth-callback?error=access_denied',
      );
      final service = RevenueCatOAuthService(
        secureStorageService: storage,
        webAuthLauncher: launcher,
      );

      await expectLater(
        service.connect(clientId: 'cid', clientSecret: 'csecret'),
        throwsA(isA<RevenueCatAuthException>()),
      );
    });
  });

  group('RevenueCatOAuthService.getValidAccessToken', () {
    test('未接続なら例外を投げる', () async {
      final service = RevenueCatOAuthService(
        secureStorageService: FakeSecureStorageService(),
      );
      await expectLater(
        service.getValidAccessToken(),
        throwsA(isA<RevenueCatAuthException>()),
      );
    });

    test('有効期限内ならリフレッシュせずそのまま返す', () async {
      final storage = FakeSecureStorageService();
      var tokenCalls = 0;
      final client = MockClient((request) async {
        tokenCalls++;
        return http.Response(
          jsonEncode({'access_token': 'atX', 'refresh_token': 'rtX', 'expires_in': 3600}),
          200,
        );
      });
      final launcher = _FixedWebAuthLauncher(
        (authUrl) =>
            'ririkan://revenuecat-oauth-callback?code=c&state=${authUrl.queryParameters['state']}',
      );
      final service = RevenueCatOAuthService(
        secureStorageService: storage,
        webAuthLauncher: launcher,
        httpClient: client,
      );
      await service.connect(clientId: 'cid', clientSecret: 'csecret');
      expect(tokenCalls, 1);

      final token = await service.getValidAccessToken();
      expect(token, 'atX');
      // 有効期限内なのでリフレッシュ(トークンエンドポイント2回目呼び出し)は発生しない。
      expect(tokenCalls, 1);
    });

    test('有効期限切れならrefresh_tokenグラントで更新し、新しい値で上書きする', () async {
      final storage = FakeSecureStorageService();
      // 最初のconnect()はexpires_in=0(即失効)で返す。
      var tokenCalls = 0;
      final client = MockClient((request) async {
        tokenCalls++;
        if (tokenCalls == 1) {
          return http.Response(
            jsonEncode({
              'access_token': 'at_old',
              'refresh_token': 'rt_old',
              'expires_in': 0,
            }),
            200,
          );
        }
        expect(request.bodyFields['grant_type'], 'refresh_token');
        expect(request.bodyFields['refresh_token'], 'rt_old');
        return http.Response(
          jsonEncode({
            'access_token': 'at_new',
            'refresh_token': 'rt_new',
            'expires_in': 3600,
          }),
          200,
        );
      });
      final launcher = _FixedWebAuthLauncher(
        (authUrl) =>
            'ririkan://revenuecat-oauth-callback?code=c&state=${authUrl.queryParameters['state']}',
      );
      final service = RevenueCatOAuthService(
        secureStorageService: storage,
        webAuthLauncher: launcher,
        httpClient: client,
      );
      await service.connect(clientId: 'cid', clientSecret: 'csecret');

      final token = await service.getValidAccessToken();
      expect(token, 'at_new');
      expect(tokenCalls, 2);
    });
  });
}
