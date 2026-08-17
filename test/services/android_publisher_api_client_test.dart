import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/android_publisher_api_client.dart';

/// テスト用のダミーRSA秘密鍵(PKCS#8 PEM)。実在のGoogleサービスアカウントでは
/// なく、`openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt` で生成した
/// 使い捨てのテスト専用鍵(このテストの外では一切使用しない)。
const _testPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCt6zniJtIAzVM0
4on9vbnJcRw7auUP1SiDCl3Jhd07fmfppS95A89zTlgImKsSqrDKRKsLpYAPnWvp
mrVcgndT+rKi0B9Nb7F1Fst5aXzqe8JmSkVsmqEH67MXEwfvJEH6pMWpPRLKKIWU
odF9yLOEfjiG+nw4ff5boAHbuUOROpCqVFhBgBASFmV9cARV/zODbkFl+eVmJcPc
UflIbW4zIwvvtqplaXZgXLFDskby2+RrIZr1Ge6MC6WOs5Zepv0BrPIAtyP27s48
wK5mVc5acdQy584Nhv9LpNDNwGr06lxB8I9yrEF/JzALbeOeOTOV49/8JDbMG0wl
muUBp+1VAgMBAAECggEAFjxb0zE5akbWG43XLKzkIwAmJuac0LBlFJPvt8M4rNGV
gYbQEf3NuSVMFhVG0gUmw0WSRNPtEpIC6QQRqfk4PnFwA2buiZz9KEY4z5YQFX6r
NR7Lz33ZlsSoygtx2T5efSgx6VhYnaYepgkmWpmdchQdMAy4cxSQv7AubKQ8IkYP
nr+IvL6Aw/XeuPUozM1KX6/Vp5R9wo7wJ6BmACsjrnyNMn6NQk8uxm39JIxjrodI
HIgMA6/tHLFpgo8DQAOL8qu9pv8ZE87hbKQV6gfJte5obCExVwvAgQSwh7b70p9S
BKHz4k2jWeA/1cgNSkfXVUTfVBTIAHyjY+DCF0usZQKBgQDX2GsGlfCPPC+N61/s
Nommr0FWintamV9K/kOjvV49Edp/1k07EtxrMYPAF67H9U+QQ3fFJiJsgKaZvtVT
9Qu2pD/BrCiqqlcrDP55lJ2mFDE3vfAPmLzVoSvRDIqQfxusBAOVzIdZEXvUB8pB
F+ZLKgauunG0MbqDcbaRGTJnDwKBgQDORhFMKYV/O4+vbgOygZddzyC/Pwe2fRKm
AcFKvaZuhYTtxkFjUc3fqE0V4TRnWGHPgFpKSHIXTjJ5teHue9pGgtUWlR8rJglJ
MXwKaKCrmROoU0+B1SZStHzsbuLTWn0vZzP+f8ESmxUr/BDMCRW5D73jaPwMNCEt
Y2Gf86YFWwKBgQCRsa6Ecn8/X+PFiwRjgGinz5Jt5OngvLga+cgUZUWQOVXghnn5
DwEjhfelmRbMOCStfy0AMX54+Nn721lJ45U1gmbaxudoU7SlBY9b59oF+YlDU/0P
ugx0subNpAaABJxcHxWAbt9JWsjX1S5Lg+NaBxMdrBIGDK8V/JK8HGLuNwKBgDeF
VJKTeoNMnNgzXHtntj5hygawCHtuHt7gCg78DRgiiC0X9/GryyYwPs9s1pYai/k2
KxdjeJIdUijAdBek7pOcE48IhGMw0b8JusFyeAy4HzpncjcYEECipB1fm14YNSnV
NYGDEYzYgVJdfofsyhQN0KatU2pVfbihz10mT8GRAoGAWPcB3tphnTylnZNMozH7
+pqqXqBu8kELl21bSesQ2xiwmCqxTHv9ugvYZ1wAYpgWcG6BQ2yZdGwbMzYjq8/7
5fzBHNQmYlp3I7VIOWNL+M6XLPWq29J1QdwM1bc+oDauCWB139z6OwG86pvBtd8A
aiqFVreSFyGMRV4nYJ2ZB/0=
-----END PRIVATE KEY-----
''';

void main() {
  String validServiceAccountJson() => jsonEncode({
        'type': 'service_account',
        'client_email': 'fake@example-project.iam.gserviceaccount.com',
        'private_key': _testPrivateKeyPem,
      });

  test('OAuth2トークン交換 → Edit作成 → トラック取得の順にAPIを呼び、'
      'productionトラックの最新リリースからReviewStatusSnapshotを組み立てる', () async {
    final calledUrls = <String>[];

    final client = MockClient((request) async {
      calledUrls.add('${request.method} ${request.url}');

      if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
        expect(request.body, contains('grant_type=urn'));
        expect(request.body, contains('assertion='));
        return http.Response(
          jsonEncode({'access_token': 'fake-access-token', 'expires_in': 3600}),
          200,
        );
      }
      if (request.url.path.endsWith('/edits')) {
        expect(request.headers['Authorization'], 'Bearer fake-access-token');
        return http.Response(jsonEncode({'id': 'edit-123'}), 200);
      }
      if (request.url.path.endsWith('/tracks')) {
        return http.Response(
          jsonEncode({
            'tracks': [
              {
                'track': 'internal',
                'releases': [
                  {
                    'name': '0.9.0',
                    'status': 'draft',
                  }
                ],
              },
              {
                'track': 'production',
                'releases': [
                  {
                    'name': '2.1.0',
                    'status': 'completed',
                    'versionCodes': ['21'],
                  }
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final apiClient = AndroidPublisherApiClient(httpClient: client);
    final snapshot = await apiClient.fetchLatestReviewStatus(
      serviceAccountJson: validServiceAccountJson(),
      packageName: 'works.petit.testapp',
      connectedAppId: 'app-1',
    );

    expect(calledUrls, hasLength(3));
    expect(snapshot, isNotNull);
    // internalではなくproductionトラックの値が使われる。
    expect(snapshot!.versionString, '2.1.0');
    expect(snapshot.statusType, ReviewStatusType.live);
    expect(snapshot.connectedAppId, 'app-1');
  });

  test('トラックが1件も無ければnullを返す', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
        return http.Response(
          jsonEncode({'access_token': 'fake-access-token', 'expires_in': 3600}),
          200,
        );
      }
      if (request.url.path.endsWith('/edits')) {
        return http.Response(jsonEncode({'id': 'edit-123'}), 200);
      }
      return http.Response(jsonEncode({'tracks': []}), 200);
    });

    final apiClient = AndroidPublisherApiClient(httpClient: client);
    final snapshot = await apiClient.fetchLatestReviewStatus(
      serviceAccountJson: validServiceAccountJson(),
      packageName: 'works.petit.testapp',
      connectedAppId: 'app-1',
    );

    expect(snapshot, isNull);
  });

  test('TrackReleaseのstatusを審査状態へマッピングする(draft/inProgress/halted/completed)',
      () async {
    Future<ReviewStatusType?> statusFor(String releaseStatus) async {
      final client = MockClient((request) async {
        if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
          return http.Response(
            jsonEncode({'access_token': 't', 'expires_in': 3600}),
            200,
          );
        }
        if (request.url.path.endsWith('/edits')) {
          return http.Response(jsonEncode({'id': 'edit-123'}), 200);
        }
        return http.Response(
          jsonEncode({
            'tracks': [
              {
                'track': 'production',
                'releases': [
                  {'name': '1.0.0', 'status': releaseStatus}
                ],
              },
            ],
          }),
          200,
        );
      });
      final apiClient = AndroidPublisherApiClient(httpClient: client);
      final snapshot = await apiClient.fetchLatestReviewStatus(
        serviceAccountJson: validServiceAccountJson(),
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      );
      return snapshot?.statusType;
    }

    expect(await statusFor('draft'), ReviewStatusType.waitingReview);
    expect(await statusFor('inProgress'), ReviewStatusType.inReview);
    expect(await statusFor('halted'), ReviewStatusType.rejected);
    expect(await statusFor('completed'), ReviewStatusType.live);
  });

  test('OAuthトークン取得が失敗(401)すると例外を投げる', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'error': 'invalid_grant'}), 401);
    });

    final apiClient = AndroidPublisherApiClient(httpClient: client);

    await expectLater(
      apiClient.fetchLatestReviewStatus(
        serviceAccountJson: validServiceAccountJson(),
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      ),
      throwsA(isA<AndroidPublisherAuthException>()),
    );
  });

  test('サービスアカウントJSONの形式が不正だとHTTP通信を行わず例外を投げる', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    final apiClient = AndroidPublisherApiClient(httpClient: client);

    await expectLater(
      apiClient.fetchLatestReviewStatus(
        serviceAccountJson: 'not a json',
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      ),
      throwsA(isA<AndroidPublisherAuthException>()),
    );
    expect(called, isFalse);
  });
}
