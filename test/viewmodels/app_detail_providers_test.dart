import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/crash_summary.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/viewmodels/app_detail_providers.dart';
import 'package:ririkan/viewmodels/dashboard_providers.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

/// 取得が常に失敗するテスト用Service。ServiceFailure が
/// UI 側の AsyncError まで実際に伝播することを検証するために使う。
class _AlwaysFailingReviewStatusService implements ReviewStatusService {
  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async =>
      const ServiceFailure(ServiceFailureReason.reviewStatus);

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async =>
      const ServiceFailure(ServiceFailureReason.rejectionDetails);

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async =>
      const ServiceFailure(ServiceFailureReason.buildFailureLogs);

  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async =>
      const ServiceFailure(ServiceFailureReason.appDiscovery);

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) async =>
      const ServiceFailure(ServiceFailureReason.crashSummaries);
}

void main() {
  const app = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    displayName: 'テストアプリ',
    sortOrder: 0,
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(_AlwaysFailingReviewStatusService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('ServiceFailure は握りつぶされず ServiceFailureException として例外伝播する', () async {
    await expectLater(
      container.read(reviewHistoryProvider(app).future),
      throwsA(isA<ServiceFailureException>()),
    );
  });

  test('伝播した例外のreasonはServiceFailure.reasonと一致する', () async {
    try {
      await container.read(reviewHistoryProvider(app).future);
      fail('例外が投げられるはず');
    } on ServiceFailureException catch (e) {
      expect(e.reason, ServiceFailureReason.reviewStatus);
    }
  });

  test('latestReviewStatusProvider も同様に例外伝播する', () async {
    await expectLater(
      container.read(latestReviewStatusProvider(app).future),
      throwsA(isA<ServiceFailureException>()),
    );
  });
}
