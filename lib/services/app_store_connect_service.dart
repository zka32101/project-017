import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'app_store_connect_api_client.dart';
import 'mock_data_service.dart';
import 'review_status_service.dart';
import 'service_result.dart';

/// iOS: App Store Connect Webhooks経由（実装は Cloud Functions中継 → FCM、設計書 Step1）。
/// 審査状態・リジェクト理由・ビルド失敗ログの取得はMVP段階ではWebhook受信サーバー
/// 未実装のためモックデータを返す（実API接続は次フェーズ）。
/// アプリ一覧取得（discoverApps）のみ、App Store Connect APIのGET /v1/appsに
/// 実接続する（Play Developer APIと異なりApple側には本物の一覧取得エンドポイントが
/// 存在するため。ユーザー指示によりこちらのみ先行実装）。
class AppStoreConnectService implements ReviewStatusService {
  AppStoreConnectService({
    MockDataService mockDataService = const MockDataService(),
    AppStoreConnectApiClient? apiClient,
  })  : _mock = mockDataService,
        _apiClient = apiClient ?? AppStoreConnectApiClient();

  final MockDataService _mock;
  final AppStoreConnectApiClient _apiClient;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async {
    try {
      final data = _mock.reviewStatusesFor(app.id, app.platform);
      return ServiceSuccess(data);
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.reviewStatus, cause: e);
    }
  }

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async {
    try {
      return ServiceSuccess(_mock.rejectionsFor(app.id));
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.rejectionDetails, cause: e);
    }
  }

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async {
    try {
      return ServiceSuccess(_mock.buildFailuresFor(app.id, app.platform));
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.buildFailureLogs, cause: e);
    }
  }

  /// apiKey には {"issuerId", "keyId", "privateKey"} をJSON化した文字列を渡すこと
  /// (AppRegistrationScreenの3つの入力欄から組み立てられる)。
  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async {
    try {
      final apps = await _apiClient.listApps(apiKey);
      return ServiceSuccess(apps);
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.appDiscovery, cause: e);
    }
  }
}
