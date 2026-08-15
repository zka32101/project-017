import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
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
}
