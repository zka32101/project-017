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
    String apiKey,
  ) async =>
      const ServiceFailure(ServiceFailureReason.appDiscovery);
}

void main() {
  Future<ConnectedApp> setupApp(ProviderContainer container) =>
      container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: '詳細画面テストアプリ',
            apiKey: 'k',
          );

  testWidgets('審査履歴タブ（デフォルト）にモックデータが表示される', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);
    final app = await setupApp(container);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/app-detail/${app.id}');
    await tester.pumpAndSettle();

    // MockDataService: iOSは '1.4.0' が審査中で返る。
    expect(find.text('v1.4.0'), findsOneWidget);
  });

  testWidgets('クラッシュ推移タブに切り替えるとモックのクラッシュデータが表示される',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);
    final app = await setupApp(container);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/app-detail/${app.id}');
    await tester.pumpAndSettle();

    await tester.tap(find.text('クラッシュ推移'));
    await tester.pumpAndSettle();

    // MockDataService.crashSummariesFor: 7日分、クラッシュフリー率99.6%固定。
    expect(find.textContaining('クラッシュフリー率 99.6%'), findsWidgets);
  });

  testWidgets('売上・DL数タブに通貨コード（JPY）付きで金額が表示される', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);
    final app = await setupApp(container);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/app-detail/${app.id}');
    await tester.pumpAndSettle();

    await tester.tap(find.text('売上・DL数'));
    await tester.pumpAndSettle();

    // 直近合計売上サマリータイルが 'JPY ...' で始まる（¥ハードコードのバグ修正の確認）。
    expect(find.textContaining('JPY '), findsWidgets);
  });

  testWidgets('リジェクト理由タブで取得失敗時にエラー表示と再試行ボタンが出る', (tester) async {
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
    final app = await setupApp(container);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/app-detail/${app.id}');
    await tester.pumpAndSettle();

    await tester.tap(find.text('リジェクト理由'));
    await tester.pumpAndSettle();

    expect(find.text('リジェクト理由の取得に失敗しました'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);

    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();

    // 再試行後も同じフェイクServiceが同じ失敗を返すため、エラー表示が維持される
    // （再試行ボタン自体がクラッシュせず動作することの確認）。
    expect(find.text('リジェクト理由の取得に失敗しました'), findsOneWidget);
  });
}
