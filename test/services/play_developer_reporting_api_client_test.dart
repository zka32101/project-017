import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/services/play_developer_reporting_api_client.dart';

/// テスト用のダミーRSA秘密鍵(PKCS#8 PEM)。実在のGoogleサービスアカウントでは
/// なく、`openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt` で生成した
/// 使い捨てのテスト専用鍵(android_publisher_api_client_test.dartと同じ鍵)。
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

  test('OAuth2トークン交換 → crashRateMetricSet:queryの順にAPIを呼び、'
      '各行をCrashSummaryへ変換する', () async {
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
      if (request.url.path.endsWith(':query')) {
        expect(request.headers['Authorization'], 'Bearer fake-access-token');
        expect(request.url.path, contains('works.petit.testapp'));
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['metrics'], contains('crashRate'));
        expect(
          requestBody['timelineSpec']['aggregationPeriod'],
          'DAILY',
        );
        return http.Response(
          jsonEncode({
            'rows': [
              {
                'startTime': {'year': 2026, 'month': 8, 'day': 10},
                'metrics': [
                  {
                    'metric': 'crashRate',
                    'decimalValue': {'value': '0.4'},
                  },
                  {
                    'metric': 'distinctUsers',
                    'decimalValue': {'value': '1000'},
                  },
                ],
              },
              {
                'startTime': {'year': 2026, 'month': 8, 'day': 11},
                'metrics': [
                  {
                    'metric': 'crashRate',
                    'decimalValue': {'value': '1.2'},
                  },
                  {
                    'metric': 'distinctUsers',
                    'decimalValue': {'value': '2000'},
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final apiClient = PlayDeveloperReportingApiClient(httpClient: client);
    final summaries = await apiClient.fetchCrashSummaries(
      serviceAccountJson: validServiceAccountJson(),
      packageName: 'works.petit.testapp',
      connectedAppId: 'app-1',
    );

    expect(calledUrls, hasLength(2));
    expect(summaries, hasLength(2));

    expect(summaries[0].date, DateTime(2026, 8, 10));
    expect(summaries[0].crashFreeRate, closeTo(99.6, 0.001));
    // distinctUsers(1000) × crashRate(0.4%) ≈ 4人の近似値。
    expect(summaries[0].crashCount, 4);
    expect(summaries[0].connectedAppId, 'app-1');

    expect(summaries[1].date, DateTime(2026, 8, 11));
    expect(summaries[1].crashFreeRate, closeTo(98.8, 0.001));
    // distinctUsers(2000) × crashRate(1.2%) = 24人。
    expect(summaries[1].crashCount, 24);
  });

  test('行が0件ならCrashSummaryの空リストを返す', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
        return http.Response(
          jsonEncode({'access_token': 'fake-access-token', 'expires_in': 3600}),
          200,
        );
      }
      return http.Response(jsonEncode({'rows': []}), 200);
    });

    final apiClient = PlayDeveloperReportingApiClient(httpClient: client);
    final summaries = await apiClient.fetchCrashSummaries(
      serviceAccountJson: validServiceAccountJson(),
      packageName: 'works.petit.testapp',
      connectedAppId: 'app-1',
    );

    expect(summaries, isEmpty);
  });

  test('OAuthトークン取得が失敗(401)すると例外を投げる', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'error': 'invalid_grant'}), 401);
    });

    final apiClient = PlayDeveloperReportingApiClient(httpClient: client);

    await expectLater(
      apiClient.fetchCrashSummaries(
        serviceAccountJson: validServiceAccountJson(),
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      ),
      throwsA(isA<PlayDeveloperReportingAuthException>()),
    );
  });

  test('crashRateMetricSet:queryが失敗(403、権限不足等)すると例外を投げる', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
        return http.Response(
          jsonEncode({'access_token': 'fake-access-token', 'expires_in': 3600}),
          200,
        );
      }
      return http.Response(jsonEncode({'error': 'permission denied'}), 403);
    });

    final apiClient = PlayDeveloperReportingApiClient(httpClient: client);

    await expectLater(
      apiClient.fetchCrashSummaries(
        serviceAccountJson: validServiceAccountJson(),
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      ),
      throwsA(isA<PlayDeveloperReportingAuthException>()),
    );
  });

  test('サービスアカウントJSONの形式が不正だとHTTP通信を行わず例外を投げる', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    final apiClient = PlayDeveloperReportingApiClient(httpClient: client);

    await expectLater(
      apiClient.fetchCrashSummaries(
        serviceAccountJson: 'not a json',
        packageName: 'works.petit.testapp',
        connectedAppId: 'app-1',
      ),
      throwsA(isA<PlayDeveloperReportingAuthException>()),
    );
    expect(called, isFalse);
  });
}
