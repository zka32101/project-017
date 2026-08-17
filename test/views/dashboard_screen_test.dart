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

  group('検索・フィルター・ソート', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> pumpDashboardWith(WidgetTester tester) async {
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.zebra',
            displayName: 'Zebra iOS',
            apiKey: 'k',
          );
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.android,
            bundleIdOrPackageName: 'works.petit.apple',
            displayName: 'Apple Android',
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
    }

    testWidgets('検索欄に入力すると名前が一致しないアプリは非表示になる', (tester) async {
      await pumpDashboardWith(tester);

      expect(find.text('Zebra iOS'), findsOneWidget);
      expect(find.text('Apple Android'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zebra');
      await tester.pumpAndSettle();

      expect(find.text('Zebra iOS'), findsOneWidget);
      expect(find.text('Apple Android'), findsNothing);
    });

    testWidgets('検索条件に一致するアプリが無いと専用メッセージが表示される', (tester) async {
      await pumpDashboardWith(tester);

      await tester.enterText(find.byType(TextField), '存在しないアプリ名');
      await tester.pumpAndSettle();

      expect(find.text('条件に一致するアプリがありません'), findsOneWidget);
      expect(find.text('Zebra iOS'), findsNothing);
      expect(find.text('Apple Android'), findsNothing);
    });

    testWidgets('プラットフォームフィルターで絞り込める', (tester) async {
      await pumpDashboardWith(tester);

      // 「iOS」はフィルターチップとカードのアバター(iOS/And)の両方に出るため、
      // ChoiceChip側だけを特定してタップする。
      await tester.tap(find.widgetWithText(ChoiceChip, 'iOS'));
      await tester.pumpAndSettle();

      expect(find.text('Zebra iOS'), findsOneWidget);
      expect(find.text('Apple Android'), findsNothing);

      // 「すべて」を選び直すと両方戻る。
      await tester.tap(find.widgetWithText(ChoiceChip, 'すべて'));
      await tester.pumpAndSettle();

      expect(find.text('Zebra iOS'), findsOneWidget);
      expect(find.text('Apple Android'), findsOneWidget);
    });

    testWidgets('名前順ソートを選ぶと表示順がアルファベット順になる', (tester) async {
      await pumpDashboardWith(tester);

      // 登録順(手動)ではZebra iOSが先。
      var titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(titles, ['Zebra iOS', 'Apple Android']);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      // CheckedPopupMenuItemはチェックマーク分のPaddingを含む領域全体がタップ
      // 対象になっており、テキスト自体のRenderBox中心はヒットテスト対象外に
      // なることがあるため警告は無視してよい(実際に選択自体は成功する)。
      await tester.tap(find.text('名前順'), warnIfMissed: false);
      await tester.pumpAndSettle();

      titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title as Text).data)
          .toList();
      expect(titles, ['Apple Android', 'Zebra iOS']);
    });
  });
}
