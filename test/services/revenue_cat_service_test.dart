import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/constants/demo_app_ids.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/revenue_summary.dart';
import 'package:ririkan/services/revenue_cat_api_client.dart';
import 'package:ririkan/services/revenue_cat_oauth_service.dart';
import 'package:ririkan/services/revenue_cat_service.dart';
import 'package:ririkan/services/service_result.dart';

class _FakeAuthProvider implements RevenueCatAuthProvider {
  _FakeAuthProvider({this.connected = true});

  final bool connected;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<String> getValidAccessToken() async {
    if (!connected) {
      throw const RevenueCatAuthException('RevenueCatと未接続です');
    }
    return 'fake-token';
  }
}

/// RevenueCatApiClientは通常のクラス(インターフェース分離なし)のため、
/// 他Serviceのフェイクと同様にextendsしてメソッドを差し替える。
class _FakeApiClient extends RevenueCatApiClient {
  _FakeApiClient({this.series = const []});

  final List<RevenueSummary> series;
  bool called = false;

  @override
  Future<String> fetchProjectId(String accessToken) async => 'proj_1';

  @override
  Future<List<RevenueSummary>> fetchRevenueSeries({
    required String accessToken,
    required String projectId,
    required String connectedAppId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    called = true;
    return series;
  }
}

void main() {
  const demoApp = ConnectedApp(
    id: demoIosAppId,
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.demo',
    displayName: 'デモアプリ',
    sortOrder: 0,
  );

  const realApp = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    displayName: 'テストアプリ',
    sortOrder: 0,
  );

  group('RevenueCatService.fetchRevenueSummary デモアプリ', () {
    test('OAuth未接続でも指定日数分のモックデータが日付昇順で返る', () async {
      final service = RevenueCatService();
      final result = await service.fetchRevenueSummary(demoApp, days: 7);

      expect(result, isA<ServiceSuccess<List<RevenueSummary>>>());
      final data = (result as ServiceSuccess<List<RevenueSummary>>).data;
      expect(data.length, 7);
      for (var i = 1; i < data.length; i++) {
        expect(data[i].date.isAfter(data[i - 1].date), isTrue);
      }
      expect(data.every((r) => r.connectedAppId == demoApp.id), isTrue);
    });

    test('デフォルトは30日分のモックデータを返す', () async {
      final service = RevenueCatService();
      final result = await service.fetchRevenueSummary(demoApp);
      final data = (result as ServiceSuccess<List<RevenueSummary>>).data;
      expect(data.length, 30);
    });
  });

  group('RevenueCatService.fetchRevenueSummary 実アプリ', () {
    test('oauthServiceを渡していなければServiceFailureになる', () async {
      final service = RevenueCatService();
      final result = await service.fetchRevenueSummary(realApp);

      expect(result, isA<ServiceFailure<List<RevenueSummary>>>());
      expect(
        (result as ServiceFailure<List<RevenueSummary>>).reason,
        ServiceFailureReason.revenueSummary,
      );
    });

    test('RevenueCat未接続ならServiceFailureになる', () async {
      final service = RevenueCatService(
        oauthService: _FakeAuthProvider(connected: false),
        apiClient: _FakeApiClient(),
      );
      final result = await service.fetchRevenueSummary(realApp);

      expect(result, isA<ServiceFailure<List<RevenueSummary>>>());
    });

    test('接続済みならAPIクライアント経由の実データをそのまま返す', () async {
      final expected = [
        RevenueSummary(
          id: 'app1_rev_2026-08-01',
          connectedAppId: realApp.id,
          date: DateTime(2026, 8, 1),
          revenue: 123.4,
          downloadCount: 0,
        ),
      ];
      final apiClient = _FakeApiClient(series: expected);
      final service = RevenueCatService(
        oauthService: _FakeAuthProvider(),
        apiClient: apiClient,
      );

      final result = await service.fetchRevenueSummary(realApp, days: 1);

      expect(result, isA<ServiceSuccess<List<RevenueSummary>>>());
      final data = (result as ServiceSuccess<List<RevenueSummary>>).data;
      expect(data, expected);
      expect(apiClient.called, isTrue);
    });

    test('APIクライアントが例外を投げるとServiceFailureになる', () async {
      final service = RevenueCatService(
        oauthService: _FakeAuthProvider(),
        apiClient: _ThrowingApiClient(),
      );
      final result = await service.fetchRevenueSummary(realApp);

      expect(result, isA<ServiceFailure<List<RevenueSummary>>>());
      expect(
        (result as ServiceFailure<List<RevenueSummary>>).reason,
        ServiceFailureReason.revenueSummary,
      );
    });
  });
}

class _ThrowingApiClient extends RevenueCatApiClient {
  @override
  Future<String> fetchProjectId(String accessToken) async {
    throw const RevenueCatApiException('boom');
  }
}
