import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/discoverable_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'service_result.dart';

/// App Store Connect / Play Console 共通インターフェース。
/// 実装は AppStoreConnectService（Webhooks中継）と PlayConsoleService（MVPはポーリング、条件1準拠）。
abstract class ReviewStatusService {
  /// タイムアウト10秒・リトライ3回（設計書 Step5）を実装側で必ず守ること。
  static const Duration timeout = Duration(seconds: 10);
  static const int maxRetries = 3;

  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  );

  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  );

  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  );

  /// APIキー1つに紐づくアカウント配下の全アプリを取得する（アプリ単位の
  /// 手動登録ではなく、まとめて取得して一括登録するフロー用）。
  /// まだ ConnectedApp として登録されていない段階の呼び出しのため、
  /// 他メソッドと異なり ConnectedApp ではなく生のAPIキー文字列を受け取る。
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(String apiKey);
}
