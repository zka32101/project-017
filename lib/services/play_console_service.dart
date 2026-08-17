import '../constants/demo_app_ids.dart';
import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'android_publisher_api_client.dart';
import 'mock_data_service.dart';
import 'review_status_service.dart';
import 'secure_storage_service.dart';
import 'service_result.dart';

/// Android: Google Play Developer API 実接続。
///
/// - discoverApps(): Play Developer APIには「アカウント配下の全アプリを一覧
///   取得する」公式エンドポイントが存在しない(Discovery Documentで確認済み、
///   既知のpackageNameに対する操作しかできない)。そのためHTTP通信は行わず、
///   ユーザーが直接入力したパッケージ名からその場でDiscoverableAppを組み立てる。
/// - fetchReviewStatus(): サービスアカウントJWTでOAuth2アクセストークンを取得し、
///   Edit作成→トラック一覧取得で最新リリースの状態(status)を実際に取得する。
///   ただしPlay Developer APIには「ポリシー審査中/リジェクト」を明示する
///   フィールドが公式には無いため、リリースの進行状況(draft/inProgress/
///   halted/completed)を近似値として扱う。
/// - fetchRejectionDetails() / fetchBuildFailureLogs(): 現状モックのまま。
///   Play Developer APIにはポリシー審査のリジェクト理由本文や、ビルド失敗の
///   詳細ログを取得する公開エンドポイントが存在しないため。
///
/// デモアプリ(lib/constants/demo_app_ids.dart)は実際のAPI認証情報を持たない
/// ため、これらのIDに対しては常にMockDataServiceのデータを返す。
class PlayConsoleService implements ReviewStatusService {
  PlayConsoleService({
    required SecureStorageService secureStorageService,
    MockDataService mockDataService = const MockDataService(),
    this.pollInterval = const Duration(minutes: 15),
    AndroidPublisherApiClient? apiClient,
  })  : _secureStorage = secureStorageService,
        _mock = mockDataService,
        _apiClient = apiClient ?? AndroidPublisherApiClient();

  final SecureStorageService _secureStorage;
  final MockDataService _mock;
  final AndroidPublisherApiClient _apiClient;

  /// Remote Config「ポーリング間隔」の初期値。実運用ではRemoteConfigServiceから注入する。
  final Duration pollInterval;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async {
    if (app.id == demoAndroidAppId) {
      return ServiceSuccess(_mock.reviewStatusesFor(app.id, app.platform));
    }
    try {
      final credential = await _secureStorage.readApiKey(app.id);
      if (credential == null || credential.isEmpty) {
        return const ServiceFailure(ServiceFailureReason.reviewStatus);
      }
      final snapshot = await _apiClient.fetchLatestReviewStatus(
        serviceAccountJson: credential,
        packageName: app.bundleIdOrPackageName,
        connectedAppId: app.id,
      );
      return ServiceSuccess(snapshot == null ? [] : [snapshot]);
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

  /// Google Play Developer API(androidpublisher v3)には「アカウント配下の
  /// 全アプリ一覧を取得する」公式エンドポイントが存在しない（Discovery
  /// Documentで確認済み、既知のpackageNameに対する操作しかできない）。
  /// そのため実際のHTTP通信は行わず、呼び出し元(AppRegistrationScreen)が
  /// ユーザーに直接入力してもらったpackageNameから DiscoverableApp を
  /// その場で組み立てるだけの処理になる。表示名はAPI経由で取得できないため
  /// packageNameから機械的に生成した仮の名前になる(あとで設定画面等での
  /// リネームは現状未対応、次フェーズ)。
  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async {
    if (knownPackageNames.isEmpty) {
      return const ServiceFailure(ServiceFailureReason.appDiscovery);
    }
    try {
      final apps = knownPackageNames
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toSet() // 重複排除
          .map((p) => DiscoverableApp(
                bundleIdOrPackageName: p,
                displayName: _guessDisplayNameFromPackageName(p),
              ))
          .toList();
      if (apps.isEmpty) {
        return const ServiceFailure(ServiceFailureReason.appDiscovery);
      }
      return ServiceSuccess(apps);
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.appDiscovery, cause: e);
    }
  }

  /// 'com.example.my_cool_app' -> 'My Cool App' のように、パッケージ名の
  /// 最後のセグメントから見た目上の仮表示名を機械的に生成する。
  static String _guessDisplayNameFromPackageName(String packageName) {
    final segments = packageName.split('.');
    final last = segments.isEmpty ? packageName : segments.last;
    final words = last
        .split(RegExp(r'[_\-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1));
    final guessed = words.join(' ');
    return guessed.isEmpty ? packageName : guessed;
  }
}
