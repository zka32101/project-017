import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/services/app_store_connect_api_client.dart';

/// テスト用のダミーEC秘密鍵(P-256、PKCS#8 PEM)。実在のApple発行キーではなく、
/// `openssl ecparam -genkey -name prime256v1 -noout | openssl pkcs8 -topk8 -nocrypt`
/// で生成した使い捨てのテスト専用鍵(このテストの外では一切使用しない)。
/// JWT署名処理が実際に完走することを確認するには、形式として妥当な鍵が必要。
const _testPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg3I48VYshlsKe8WrG
LBzvwrY0uaJ7aVXyUENM/bICbO6hRANCAAQfSLDNyPre0ar1w7DqbM4QvWXLN3kV
sfhZo1YP5tKq93cre+YOxdTPYHTNTUe6IH8SDNnd55hy/oBX+gpfVpSt
-----END PRIVATE KEY-----
''';

/// 内部のJWTを検証はせず(公開鍵を持たないため)、header/payloadだけ
/// base64url decodeして中身を確認する。
Map<String, dynamic> _decodeJwtSegment(String token, int index) {
  final parts = token.split('.');
  final normalized = base64Url.normalize(parts[index]);
  return jsonDecode(utf8.decode(base64Url.decode(normalized)))
      as Map<String, dynamic>;
}

void main() {
  String validCredentialJson() => jsonEncode({
        'issuerId': 'issuer-abc',
        'keyId': 'key-xyz',
        'privateKey': _testPrivateKeyPem,
      });

  test('正しい認証情報で呼ぶと、Bearerトークン付きでGET /v1/appsを叩き、応答を'
      'DiscoverableAppへ変換する', () async {
    Uri? capturedUri;
    String? capturedAuthHeader;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedAuthHeader = request.headers['Authorization'];
      return http.Response(
        jsonEncode({
          'data': [
            {
              'type': 'apps',
              'id': '1',
              'attributes': {
                'name': 'My Awesome App',
                'bundleId': 'works.petit.awesome',
              },
            },
            {
              'type': 'apps',
              'id': '2',
              'attributes': {
                'name': null,
                'bundleId': 'works.petit.noname',
              },
            },
          ],
        }),
        200,
      );
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);
    final apps = await apiClient.listApps(validCredentialJson());

    expect(capturedUri.toString(), 'https://api.appstoreconnect.apple.com/v1/apps?limit=200');
    expect(capturedAuthHeader, startsWith('Bearer '));

    expect(apps, hasLength(2));
    expect(apps[0].bundleIdOrPackageName, 'works.petit.awesome');
    expect(apps[0].displayName, 'My Awesome App');
    // nameがnullの場合はbundleIdをそのままdisplayNameとして使う。
    expect(apps[1].displayName, 'works.petit.noname');
  });

  test('JWTのheader/payloadに正しいissuer/audience/kidが載る', () async {
    late String sentToken;
    final client = MockClient((request) async {
      sentToken = request.headers['Authorization']!.substring('Bearer '.length);
      return http.Response(jsonEncode({'data': []}), 200);
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);
    await apiClient.listApps(validCredentialJson());

    final header = _decodeJwtSegment(sentToken, 0);
    final payload = _decodeJwtSegment(sentToken, 1);

    expect(header['alg'], 'ES256');
    expect(header['kid'], 'key-xyz');
    expect(payload['iss'], 'issuer-abc');
    expect(payload['aud'], 'appstoreconnect-v1');
    expect(payload['iat'], isNotNull);
    expect(payload['exp'], isNotNull);
  });

  test('links.nextがある限りページを辿り、201件超のアカウントでも全件取得する',
      () async {
    final calledUris = <String>[];
    final client = MockClient((request) async {
      calledUris.add(request.url.toString());
      if (calledUris.length == 1) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'type': 'apps',
                'id': '1',
                'attributes': {'name': 'App One', 'bundleId': 'works.petit.one'},
              },
            ],
            'links': {
              'next':
                  'https://api.appstoreconnect.apple.com/v1/apps?limit=200&cursor=PAGE2',
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': [
            {
              'type': 'apps',
              'id': '2',
              'attributes': {'name': 'App Two', 'bundleId': 'works.petit.two'},
            },
          ],
          // 最終ページにはlinks.nextが無い。
          'links': <String, dynamic>{},
        }),
        200,
      );
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);
    final apps = await apiClient.listApps(validCredentialJson());

    expect(calledUris, hasLength(2));
    expect(calledUris[1], contains('cursor=PAGE2'));
    expect(apps, hasLength(2));
    expect(apps.map((a) => a.bundleIdOrPackageName),
        containsAll(['works.petit.one', 'works.petit.two']));
  });

  test('アプリが0件の応答なら空リストを返す(discoverApps側で"見つからない"扱いにする)',
      () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'data': []}), 200);
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);
    final apps = await apiClient.listApps(validCredentialJson());

    expect(apps, isEmpty);
  });

  test('HTTPエラー応答(401等)は例外を投げる', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'errors': []}), 401);
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);

    await expectLater(
      apiClient.listApps(validCredentialJson()),
      throwsA(isA<AppStoreConnectAuthException>()),
    );
  });

  test('認証情報のJSONが壊れている場合はHTTP通信を行わず例外を投げる', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    final apiClient = AppStoreConnectApiClient(httpClient: client);

    await expectLater(
      apiClient.listApps('not a json'),
      throwsA(isA<AppStoreConnectAuthException>()),
    );
    expect(called, isFalse);
  });

  test('Issuer ID等が欠けている場合は例外を投げる', () async {
    final apiClient = AppStoreConnectApiClient(httpClient: MockClient((_) async {
      fail('この場合はHTTP通信が発生してはいけない');
    }));

    await expectLater(
      apiClient.listApps(jsonEncode({'issuerId': '', 'keyId': 'k', 'privateKey': 'p'})),
      throwsA(isA<AppStoreConnectAuthException>()),
    );
  });
}
