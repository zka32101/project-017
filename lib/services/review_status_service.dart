import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/crash_summary.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'service_result.dart';

/// App Store Connect / Play Console 共通インターフェース。
/// 実装は AppStoreConnectService と PlayConsoleService の両方とも、呼び出し
/// 側（画面）が明示的に叩いた時にAPIを読みに行くポーリング方式（このアプリ
/// はバックエンドを持たないため、AppleからのWebhook配信を受信する仕組み
/// 自体が存在しない。ダッシュボードのリアルタイム自動更新ではなく、画面を
/// 開いた/再試行した時点の最新状態を取得する設計）。
abstract class ReviewStatusService {
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  );

  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  );

  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  );

  /// クラッシュ率の日次推移を取得する。
  ///
  /// 注意: Apple公式のApp Store Connect APIにはクラッシュ率を取得できる
  /// 公開エンドポイントが存在しないため、iOS実装(AppStoreConnectService)は
  /// 引き続きMockDataServiceのデータを返す。Android実装(PlayConsoleService)は
  /// Play Developer Reporting API(vitals.crashrate.query)による実データを返す。
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  );

  /// APIキー1つに紐づくアカウント配下のアプリを取得する（アプリ単位の
  /// 手動登録ではなく、まとめて取得して一括登録するフロー用）。
  /// まだ ConnectedApp として登録されていない段階の呼び出しのため、
  /// 他メソッドと異なり ConnectedApp ではなく生のAPIキー文字列を受け取る。
  ///
  /// 注意: App Store Connect APIには「アカウント配下の全アプリ一覧取得」の
  /// 公式エンドポイント(GET /v1/apps)が存在するが、Google Play Developer API
  /// にはそれに相当するエンドポイントが存在しない(既知のpackageNameに対する
  /// 操作しかできない)。そのためAndroid側では knownPackageNames に
  /// あらかじめユーザーが入力したパッケージ名を渡す必要があり、それを基に
  /// DiscoverableApp を組み立てる(iOS側ではこの引数は無視される)。
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  });
}
