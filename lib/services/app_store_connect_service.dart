import '../constants/demo_app_ids.dart';
import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/crash_summary.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'app_store_connect_api_client.dart';
import 'mock_data_service.dart';
import 'review_status_service.dart';
import 'secure_storage_service.dart';
import 'service_result.dart';

/// iOS: App Store Connect API 実接続。
///
/// - discoverApps(): GET /v1/apps でアカウント配下の全アプリを実際に取得する。
/// - fetchReviewStatus(): GET /v1/apps/{id}/appStoreVersions で最新バージョンの
///   審査状態(appStoreState)を実際に取得する。
/// - fetchRejectionDetails() / fetchBuildFailureLogs() / fetchCrashSummaries():
///   現状モックのまま。Apple公式のApp Store Connect APIには、Resolution
///   Centerのリジェクト理由本文や、ビルド失敗の詳細ログ、クラッシュ率を
///   取得する公開エンドポイントが存在しない(非公式・非公開の内部API
///   (fastlane/spaceshipが使う"iris"等)を使えば不可能ではないが、
///   ドキュメント化されておらず予告なく変更・遮断されるリスクがあるため、
///   公式に対応方法が用意されるまでは実装しない)。
///
/// デモアプリ(lib/constants/demo_app_ids.dart)は実際のAPI認証情報を持たない
/// ため、これらのIDに対しては常にMockDataServiceのデータを返す。
class AppStoreConnectService implements ReviewStatusService {
  AppStoreConnectService({
    required SecureStorageService secureStorageService,
    MockDataService mockDataService = const MockDataService(),
    AppStoreConnectApiClient? apiClient,
  })  : _secureStorage = secureStorageService,
        _mock = mockDataService,
        _apiClient = apiClient ?? AppStoreConnectApiClient();

  final SecureStorageService _secureStorage;
  final MockDataService _mock;
  final AppStoreConnectApiClient _apiClient;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async {
    if (isDemoAppId(app.id)) {
      return ServiceSuccess(_mock.reviewStatusesFor(app.id, app.platform));
    }
    return guardServiceCall(ServiceFailureReason.reviewStatus, () async {
      final credential = await _secureStorage.readApiKey(app.id);
      if (credential == null || credential.isEmpty) {
        throw StateError('APIキーが登録されていません');
      }
      final snapshot = await _apiClient.fetchLatestReviewStatus(
        credentialJson: credential,
        bundleId: app.bundleIdOrPackageName,
        connectedAppId: app.id,
      );
      return snapshot == null ? <ReviewStatusSnapshot>[] : [snapshot];
    });
  }

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) =>
      guardServiceCall(
        ServiceFailureReason.rejectionDetails,
        () async => _mock.rejectionsFor(app.id),
      );

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) =>
      guardServiceCall(
        ServiceFailureReason.buildFailureLogs,
        () async => _mock.buildFailuresFor(app.id, app.platform),
      );

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) =>
      guardServiceCall(
        ServiceFailureReason.crashSummaries,
        () async => _mock.crashSummariesFor(app.id),
      );

  /// apiKey には {"issuerId", "keyId", "privateKey"} をJSON化した文字列を渡すこと
  /// (AppRegistrationScreenの3つの入力欄から組み立てられる)。
  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) =>
      guardServiceCall(
        ServiceFailureReason.appDiscovery,
        () => _apiClient.listApps(apiKey),
      );
}
