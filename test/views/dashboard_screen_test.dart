import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/crash_summary.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/notification_service.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/viewmodels/app_review_management_notifier.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/dashboard_providers.dart';
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

/// 常に固定のReviewStatusSnapshotを返すテスト用Service。
/// 手動ステータス上書きが自動取得値より優先して表示されること・
/// 次回の実取得成功で上書きが自動的にクリアされることを検証するために使う。
class _FixedReviewStatusService implements ReviewStatusService {
  _FixedReviewStatusService(this.status);

  // 審査状態の個別通知テストでは、同じインスタンスのままstatusを書き換えて
  // からlatestReviewStatusProviderをinvalidateし、「実取得のたびに違う状態が
  // 返ってくる」状況を再現する。
  ReviewStatusType status;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async =>
      ServiceSuccess([
        ReviewStatusSnapshot(
          id: '${app.id}_latest',
          connectedAppId: app.id,
          versionString: '1.0.0',
          statusType: status,
          fetchedAt: DateTime(2026, 8, 5),
        ),
      ]);

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);
}

void main() {
  testWidgets(
      '手動ステータス上書きは自動取得値より優先して表示され、'
      '次回の実取得成功で自動的にクリアされる', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(_FixedReviewStatusService(ReviewStatusType.approved)),
      ],
    );
    addTearDown(container.dispose);

    final app = await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'テストアプリ',
          apiKey: 'k',
        );

    // 管理タブでの手動上書き操作を模して、直接notifier経由で設定する
    // (Widget操作は別途app_detail_screen_test.dart側で検証)。
    await container
        .read(appReviewManagementProvider(app.id).notifier)
        .setManualStatusOverride(ReviewStatusType.rejected);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    // 自動取得値(approved)ではなく手動上書き(rejected)が「（手動）」付きで表示される。
    expect(find.textContaining('リジェクト'), findsOneWidget);
    expect(find.textContaining('（手動）'), findsOneWidget);
    expect(find.textContaining('承認済み'), findsNothing);

    // 明示的な再取得(retry相当)が成功すると、手動上書きは自動的にクリアされ、
    // 自動取得値(approved)がそのまま表示されるようになる。
    container.invalidate(latestReviewStatusProvider(app));
    await tester.pumpAndSettle();

    expect(find.textContaining('承認済み'), findsOneWidget);
    expect(find.textContaining('（手動）'), findsNothing);
    expect(
      container.read(appReviewManagementProvider(app.id)).manualStatusOverride,
      isNull,
    );
  });

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

    testWidgets('登録アプリが1件以上あると全アプリエクスポートアイコンが表示され、'
        'タップで/export-allへ遷移する', (tester) async {
      await pumpDashboardWith(tester);

      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();

      expect(find.text('全アプリ集約エクスポート'), findsOneWidget);
    });
  });

  group('大量アプリ管理（要注意フィルター・タグフィルター・一括選択削除）', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
          // iOSはリジェクト(要注意)、Androidは承認済み(要注意でない)固定にして
          // 要注意フィルターの絞り込みを検証する。
          reviewStatusServiceProvider(PlatformType.ios)
              .overrideWithValue(_FixedReviewStatusService(ReviewStatusType.rejected)),
          reviewStatusServiceProvider(PlatformType.android)
              .overrideWithValue(_FixedReviewStatusService(ReviewStatusType.approved)),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets('要注意フィルターを選ぶとリジェクト/審査中のアプリだけ表示される', (tester) async {
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.rejected',
            displayName: 'リジェクトApp',
            apiKey: 'k',
          );
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.android,
            bundleIdOrPackageName: 'works.petit.approved',
            displayName: '承認済みApp',
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

      expect(find.text('リジェクトApp'), findsOneWidget);
      expect(find.text('承認済みApp'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '要注意（1）'));
      await tester.pumpAndSettle();

      expect(find.text('リジェクトApp'), findsOneWidget);
      expect(find.text('承認済みApp'), findsNothing);
    });

    testWidgets('タグを設定したアプリはタグチップで絞り込める', (tester) async {
      final a = await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.a',
            displayName: 'AppA',
            apiKey: 'k',
          );
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.android,
            bundleIdOrPackageName: 'works.petit.b',
            displayName: 'AppB',
            apiKey: 'k',
          );
      await container.read(connectedAppsProvider.notifier).setTags(a.id, ['自社']);

      final router = buildAppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapWithLocalizedRouter(router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AppA'), findsOneWidget);
      expect(find.text('AppB'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '自社'));
      await tester.pumpAndSettle();

      expect(find.text('AppA'), findsOneWidget);
      expect(find.text('AppB'), findsNothing);
    });

    testWidgets('選択モードでチェックした複数アプリを一括削除できる', (tester) async {
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.a',
            displayName: 'AppA',
            apiKey: 'k',
          );
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.android,
            bundleIdOrPackageName: 'works.petit.b',
            displayName: 'AppB',
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

      // 選択モードに入る。
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      expect(find.text('0件選択中'), findsOneWidget);

      // AppAだけチェックする。
      await tester.tap(find.widgetWithText(ListTile, 'AppA'));
      await tester.pumpAndSettle();
      expect(find.text('1件選択中'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('選択した1件のアプリを削除しますか？'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();

      // 削除後は選択モードを抜け、AppAだけが消える。
      expect(find.text('AppA'), findsNothing);
      expect(find.text('AppB'), findsOneWidget);
      expect(find.text('リリカン'), findsOneWidget);
    });
  });

  group('審査状態の個別通知（Should機能）', () {
    testWidgets('通知が有効な場合、実取得のたびに状態が変わると個別通知が発火する',
        (tester) async {
      final service = _FixedReviewStatusService(ReviewStatusType.inReview);
      final notification = FakeNotificationService();
      final secureStorage = FakeSecureStorageService();
      await secureStorage.writeValue(
        key: notificationsEnabledStorageKey,
        value: 'true',
      );
      final container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(secureStorage),
          localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
          notificationServiceProvider.overrideWithValue(notification),
          reviewStatusServiceProvider(PlatformType.ios)
              .overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final app = await container.read(connectedAppsProvider.notifier).registerApp(
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

      // 初回取得(inReview)は比較対象が無いため通知しない。
      expect(notification.statusChangeNotificationCount, 0);

      // 状態がrejectedへ変わって再取得される(例: リトライ)と通知が1件発火する。
      service.status = ReviewStatusType.rejected;
      container.invalidate(latestReviewStatusProvider(app));
      await tester.pumpAndSettle();

      expect(notification.statusChangeNotificationCount, 1);
      expect(notification.lastNotifiedStatus, ReviewStatusType.rejected);

      // 同じrejectedのまま再取得しても、変化が無ければ通知は増えない。
      container.invalidate(latestReviewStatusProvider(app));
      await tester.pumpAndSettle();

      expect(notification.statusChangeNotificationCount, 1);
    });

    testWidgets('通知設定がオフの場合は状態が変化しても通知しない', (tester) async {
      final service = _FixedReviewStatusService(ReviewStatusType.inReview);
      final notification = FakeNotificationService();
      final container = ProviderContainer(
        overrides: [
          // notificationsEnabledStorageKeyを書き込まない=オフのまま(初期値)。
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
          notificationServiceProvider.overrideWithValue(notification),
          reviewStatusServiceProvider(PlatformType.ios)
              .overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final app = await container.read(connectedAppsProvider.notifier).registerApp(
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

      service.status = ReviewStatusType.rejected;
      container.invalidate(latestReviewStatusProvider(app));
      await tester.pumpAndSettle();

      expect(notification.statusChangeNotificationCount, 0);
    });
  });
}
