import '../constants/demo_app_ids.dart';
import '../models/connected_app.dart';
import '../models/revenue_summary.dart';
import 'revenue_cat_api_client.dart';
import 'revenue_cat_oauth_service.dart';
import 'service_result.dart';

/// 売上・DL数サマリー（Should機能、RevenueCat API連携）。
///
/// RevenueCatのCharts & Metrics APIはOAuth 2.0接続(RevenueCatOAuthService)が
/// 必要なため、App Store Connect/Play Consoleのようなアプリ単位のAPIキーとは
/// 異なり、アプリ全体で1回だけ接続する(設定画面から)。デモアプリ
/// (demo-app-ios/demo-app-android)は接続の有無に関わらず常にモックデータを
/// 返す(ドッグフーディング用の固定表示を維持)。それ以外の実アプリは、
/// 未接続の場合ServiceFailureを返す(サイレントにモックへフォールバックしない)。
class RevenueCatService {
  RevenueCatService({
    RevenueCatAuthProvider? oauthService,
    RevenueCatApiClient? apiClient,
  })  : _oauth = oauthService,
        _apiClient = apiClient ?? RevenueCatApiClient();

  /// 未接続時にも動作させたい呼び出し元(デモアプリ表示)向けに、OAuth無しの
  /// コンストラクタも許容する。実アプリのfetchRevenueSummaryを呼ぶ場合は
  /// oauthServiceを渡すこと(渡さない場合は常にServiceFailureになる)。
  final RevenueCatAuthProvider? _oauth;
  final RevenueCatApiClient _apiClient;
  final _mock = const _MockRevenue();

  Future<ServiceResult<List<RevenueSummary>>> fetchRevenueSummary(
    ConnectedApp app, {
    int days = 30,
  }) async {
    if (app.id == demoIosAppId || app.id == demoAndroidAppId) {
      return ServiceSuccess(_mock.revenueFor(app.id, days: days));
    }
    final oauth = _oauth;
    if (oauth == null) {
      return const ServiceFailure(ServiceFailureReason.revenueSummary);
    }
    try {
      if (!await oauth.isConnected()) {
        return const ServiceFailure(ServiceFailureReason.revenueSummary);
      }
      final accessToken = await oauth.getValidAccessToken();
      final projectId = await _apiClient.fetchProjectId(accessToken);
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));
      final data = await _apiClient.fetchRevenueSeries(
        accessToken: accessToken,
        projectId: projectId,
        connectedAppId: app.id,
        startDate: startDate,
        endDate: endDate,
      );
      return ServiceSuccess(data);
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.revenueSummary, cause: e);
    }
  }
}

/// デモアプリ向けの固定疑似データ。RevenueCat未接続でもダッシュボードの
/// Aha Moment動線を検証できるようにするための決定的なモック。
class _MockRevenue {
  const _MockRevenue();

  List<RevenueSummary> revenueFor(String connectedAppId, {int days = 30}) {
    final now = DateTime(2026, 8, 5);
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      // 単純な右肩上がりの疑似データ（UI検証用）
      final baseRevenue = 800.0 + i * 12.0;
      final baseDownloads = 15 + (i % 5);
      return RevenueSummary(
        id: '${connectedAppId}_rev_$i',
        connectedAppId: connectedAppId,
        date: date,
        revenue: baseRevenue,
        downloadCount: baseDownloads,
      );
    });
  }
}
