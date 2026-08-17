import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'mock_data_service.dart';
import 'review_status_service.dart';
import 'service_result.dart';

/// Android: MVPはPlay Developer APIポーリング方式（Pub/Sub未実装、条件1準拠）。
/// ポーリング間隔はRemote Configで調整可能にする設計（defaultPollIntervalはプレースホルダー）。
class PlayConsoleService implements ReviewStatusService {
  PlayConsoleService({
    MockDataService mockDataService = const MockDataService(),
    this.pollInterval = const Duration(minutes: 15),
  }) : _mock = mockDataService;

  final MockDataService _mock;

  /// Remote Config「ポーリング間隔」の初期値。実運用ではRemoteConfigServiceから注入する。
  final Duration pollInterval;

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
