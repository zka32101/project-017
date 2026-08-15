import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

/// 取得が常に失敗するテスト用Service（app_detail_providers_test.dartと同じ形）。
class _AlwaysFailingReviewStatusService implements ReviewStatusService {
  int fetchCallCount = 0;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async {
    fetchCallCount++;
    return const ServiceFailure(ServiceFailureReason.reviewStatus);
  }

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
    String apiKey,
  ) async =>
      const ServiceFailure(ServiceFailureReason.appDiscovery);
}

void main() {
  testWidgets('審査状態の取得に失敗すると再試行アイコンが表示され、タップで再取得される',
      (tester) async {
    final failingService = _AlwaysFailingReviewStatusService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(failingService),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'テストアプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(failingService.fetchCallCount, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    // 再試行アイコンをタップすると latestReviewStatusProvider が再度呼ばれる
    // （ref.invalidate による再フェッチ、PR #1で追加した挙動）。
    expect(failingService.fetchCallCount, 2);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
