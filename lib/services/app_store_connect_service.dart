import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import 'mock_data_service.dart';
import 'review_status_service.dart';
import 'service_result.dart';

/// iOS: App Store Connect Webhooks経由（実装は Cloud Functions中継 → FCM、設計書 Step1）。
/// MVP段階ではWebhook受信サーバー未実装のため、クライアント側は初回スキャン時に
/// このService経由でモックデータを返す（実API接続は次フェーズ、リジェクト理由の構造化取得可否は
/// 実装着手時に最新API仕様を要検索・設計書 Step4 注記）。
class AppStoreConnectService implements ReviewStatusService {
  AppStoreConnectService({MockDataService mockDataService = const MockDataService()})
      : _mock = mockDataService;

  final MockDataService _mock;

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
}
