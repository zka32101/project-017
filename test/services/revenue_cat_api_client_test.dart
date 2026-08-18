import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/services/revenue_cat_api_client.dart';

void main() {
  group('RevenueCatApiClient.fetchProjectId', () {
    test('projects配列の先頭要素のidを返す', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.revenuecat.com/v2/projects');
        expect(request.headers['Authorization'], 'Bearer tok');
        return http.Response(
          jsonEncode({
            'projects': [
              {'id': 'proj_1'},
              {'id': 'proj_2'},
            ],
          }),
          200,
        );
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      final id = await apiClient.fetchProjectId('tok');
      expect(id, 'proj_1');
    });

    test('projectsが空なら例外を投げる', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'projects': []}), 200);
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      await expectLater(
        apiClient.fetchProjectId('tok'),
        throwsA(isA<RevenueCatApiException>()),
      );
    });

    test('HTTPエラー(401)なら例外を投げる', () async {
      final client = MockClient((request) async {
        return http.Response('unauthorized', 401);
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      await expectLater(
        apiClient.fetchProjectId('tok'),
        throwsA(isA<RevenueCatApiException>()),
      );
    });
  });

  group('RevenueCatApiClient.fetchRevenueSeries', () {
    test('series[0].data の各ポイントをRevenueSummaryへ変換する（日付フィールドあり）', () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          '/v2/projects/proj_1/charts/revenue',
        );
        expect(request.url.queryParameters['resolution'], 'day');
        expect(request.url.queryParameters['start_date'], '2026-08-01');
        expect(request.url.queryParameters['end_date'], '2026-08-02');
        return http.Response(
          jsonEncode({
            'series': [
              {
                'data': [
                  {'date': '2026-08-01', 'value': 100.5},
                  {'date': '2026-08-02', 'value': 200.0},
                ],
              },
            ],
          }),
          200,
        );
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      final data = await apiClient.fetchRevenueSeries(
        accessToken: 'tok',
        projectId: 'proj_1',
        connectedAppId: 'app-1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
      );

      expect(data, hasLength(2));
      expect(data[0].date, DateTime(2026, 8, 1));
      expect(data[0].revenue, 100.5);
      expect(data[0].downloadCount, 0);
      expect(data[0].connectedAppId, 'app-1');
      expect(data[1].date, DateTime(2026, 8, 2));
      expect(data[1].revenue, 200.0);
    });

    test('トップレベルdataのみの形でも変換でき、日付が無ければstart_dateからの経過日数で補う',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'value': 10.0},
              {'value': 20.0},
            ],
          }),
          200,
        );
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      final data = await apiClient.fetchRevenueSeries(
        accessToken: 'tok',
        projectId: 'proj_1',
        connectedAppId: 'app-1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
      );

      expect(data, hasLength(2));
      expect(data[0].date, DateTime(2026, 8, 1));
      expect(data[1].date, DateTime(2026, 8, 2));
    });

    test('データポイントが無ければ空リストを返す', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      final data = await apiClient.fetchRevenueSeries(
        accessToken: 'tok',
        projectId: 'proj_1',
        connectedAppId: 'app-1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 2),
      );
      expect(data, isEmpty);
    });

    test('HTTPエラーなら例外を投げる', () async {
      final client = MockClient((request) async {
        return http.Response('forbidden', 403);
      });
      final apiClient = RevenueCatApiClient(httpClient: client);
      await expectLater(
        apiClient.fetchRevenueSeries(
          accessToken: 'tok',
          projectId: 'proj_1',
          connectedAppId: 'app-1',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 2),
        ),
        throwsA(isA<RevenueCatApiException>()),
      );
    });
  });
}
