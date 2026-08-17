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
}

void main() {
  testWidgets('取得に成功すると自動的にダッシュボードへ遷移する', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        // AppStoreConnectService.fetchReviewStatusは実API接続になっているため、
        // 実ネットワーク呼び出しで失敗しないよう明示的にフェイクへ差し替える。
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(FakeReviewStatusService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'スキャン対象アプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/initial-scan');
    // MockDataServiceは実質同期的に解決するため、初期フレームの「取得中」表示は
    // 検証せず、最終的にダッシュボードへ自動遷移することだけを確認する。
    await tester.pumpAndSettle();

    // initialScanProvider が AsyncData になった時点で自動的に /dashboard へ遷移する。
    expect(find.text('スキャン対象アプリ'), findsWidgets);
  });

  testWidgets('取得に失敗すると「ダッシュボードへ進む」ボタンが表示され、タップで進める',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(_AlwaysFailingReviewStatusService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'スキャン失敗アプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/initial-scan');
    // この画面は常時 CircularProgressIndicator（無限アニメーション）を表示しており、
    // かつ失敗時は自動遷移しないため画面上に残り続ける。pumpAndSettle はアニメーションが
    // 収まるまで待ち続けてタイムアウトするため、固定回数のpumpで代替する。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('ダッシュボードへ進む'), findsOneWidget);

    // タップ後は /dashboard へ遷移し、この画面の無限アニメーションは残らないため
    // 通常通り pumpAndSettle で待ち切ってよい。
    await tester.tap(find.text('ダッシュボードへ進む'));
    await tester.pumpAndSettle();

    expect(find.text('スキャン失敗アプリ'), findsWidgets);
  });
}
