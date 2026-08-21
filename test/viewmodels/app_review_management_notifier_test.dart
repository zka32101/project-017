import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/app_review_management.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/viewmodels/app_review_management_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

import '../test_utils/fakes.dart';

/// load()/save()の戻り値を差し込め、saveManagement()の呼び出しを記録できる
/// フェイク。appReviewManagementBootstrapProviderと各setterの永続化検証に使う。
class _SpyLocalStoreService extends LocalStoreService {
  _SpyLocalStoreService({AppReviewManagement? initial}) : _stored = initial;

  AppReviewManagement? _stored;
  int saveManagementCallCount = 0;

  @override
  Future<LocalState?> load() async => null;

  @override
  Future<void> save(LocalState state) async {}

  @override
  Future<AppReviewManagement?> loadManagement(String connectedAppId) async =>
      _stored;

  @override
  Future<void> saveManagement(
    String connectedAppId,
    AppReviewManagement info,
  ) async {
    _stored = info;
    saveManagementCallCount++;
  }
}

void main() {
  late ProviderContainer container;
  late _SpyLocalStoreService spy;

  setUp(() {
    spy = _SpyLocalStoreService();
    container = ProviderContainer(
      overrides: [localStoreServiceProvider.overrideWithValue(spy)],
    );
  });
  tearDown(() => container.dispose());

  group('AppReviewManagementNotifier', () {
    test('初期状態は空(未設定)', () {
      final state = container.read(appReviewManagementProvider('app1'));
      expect(state.isEmpty, isTrue);
    });

    test('setManualStatusOverrideで手動上書きが設定され、永続化される', () async {
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.setManualStatusOverride(ReviewStatusType.rejected);

      expect(
        container.read(appReviewManagementProvider('app1')).manualStatusOverride,
        ReviewStatusType.rejected,
      );
      expect(spy.saveManagementCallCount, 1);
    });

    test('setSubmittedAt/setReviewStartedAt/setNoteはそれぞれ他フィールドを保持したまま更新する',
        () async {
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.setManualStatusOverride(ReviewStatusType.inReview);
      await notifier.setSubmittedAt(DateTime(2026, 8, 1));
      await notifier.setReviewStartedAt(DateTime(2026, 8, 3));
      await notifier.setNote('サポート対応中');

      final state = container.read(appReviewManagementProvider('app1'));
      expect(state.manualStatusOverride, ReviewStatusType.inReview);
      expect(state.submittedAt, DateTime(2026, 8, 1));
      expect(state.reviewStartedAt, DateTime(2026, 8, 3));
      expect(state.note, 'サポート対応中');
    });

    test('clearManualStatusOverrideAfterFetchは上書き未設定なら何もしない(永続化も呼ばれない)',
        () async {
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.clearManualStatusOverrideAfterFetch();

      expect(spy.saveManagementCallCount, 0);
    });

    test(
        'clearManualStatusOverrideAfterFetchは上書きをクリアする(他フィールドは維持、'
        '次回の実取得成功時に自動的に上書きを解除するための挙動)', () async {
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.setManualStatusOverride(ReviewStatusType.rejected);
      await notifier.setNote('メモは消えない');

      await notifier.clearManualStatusOverrideAfterFetch();

      final state = container.read(appReviewManagementProvider('app1'));
      expect(state.manualStatusOverride, isNull);
      expect(state.note, 'メモは消えない');
    });
  });

  group('AppReviewManagementNotifier.recordFetchedStatus（審査状態の個別通知）', () {
    const app = ConnectedApp(
      id: 'app1',
      userId: 'u1',
      platform: PlatformType.ios,
      bundleIdOrPackageName: 'works.petit.app1',
      displayName: 'テストアプリ',
      sortOrder: 0,
    );

    test('初回取得時(lastKnownStatusが未設定)は記録するだけで通知しない', () async {
      final notification = FakeNotificationService();
      final notifier = container.read(appReviewManagementProvider('app1').notifier);

      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.waitingReview,
        notificationService: notification,
        notificationsEnabled: true,
      );

      expect(notification.statusChangeNotificationCount, 0);
      expect(
        container.read(appReviewManagementProvider('app1')).lastKnownStatus,
        ReviewStatusType.waitingReview,
      );
      expect(spy.saveManagementCallCount, 1);
    });

    test('前回と同じ状態なら永続化も通知もしない', () async {
      final notification = FakeNotificationService();
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.inReview,
        notificationService: notification,
        notificationsEnabled: true,
      );
      final countAfterFirst = spy.saveManagementCallCount;

      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.inReview,
        notificationService: notification,
        notificationsEnabled: true,
      );

      expect(notification.statusChangeNotificationCount, 0);
      expect(spy.saveManagementCallCount, countAfterFirst);
    });

    test('前回から状態が変化していて通知が有効なら個別通知が発火する', () async {
      final notification = FakeNotificationService();
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.inReview,
        notificationService: notification,
        notificationsEnabled: true,
      );

      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.rejected,
        notificationService: notification,
        notificationsEnabled: true,
      );

      expect(notification.statusChangeNotificationCount, 1);
      expect(notification.lastNotifiedApp, app);
      expect(notification.lastNotifiedStatus, ReviewStatusType.rejected);
      expect(
        container.read(appReviewManagementProvider('app1')).lastKnownStatus,
        ReviewStatusType.rejected,
      );
    });

    test('状態が変化していても通知が無効(notificationsEnabled=false)なら通知しないが記録はする',
        () async {
      final notification = FakeNotificationService();
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.inReview,
        notificationService: notification,
        notificationsEnabled: true,
      );

      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.rejected,
        notificationService: notification,
        notificationsEnabled: false,
      );

      expect(notification.statusChangeNotificationCount, 0);
      expect(
        container.read(appReviewManagementProvider('app1')).lastKnownStatus,
        ReviewStatusType.rejected,
      );
    });

    test('手動上書き・メモなど他フィールドは変更しない', () async {
      final notification = FakeNotificationService();
      final notifier = container.read(appReviewManagementProvider('app1').notifier);
      await notifier.setManualStatusOverride(ReviewStatusType.approved);
      await notifier.setNote('メモ');

      await notifier.recordFetchedStatus(
        app: app,
        status: ReviewStatusType.inReview,
        notificationService: notification,
        notificationsEnabled: true,
      );

      final state = container.read(appReviewManagementProvider('app1'));
      expect(state.manualStatusOverride, ReviewStatusType.approved);
      expect(state.note, 'メモ');
      expect(state.lastKnownStatus, ReviewStatusType.inReview);
    });
  });

  group('appReviewManagementBootstrapProvider', () {
    test('永続化データが無ければ初期状態(空)のまま', () async {
      await container.read(appReviewManagementBootstrapProvider('app1').future);
      expect(container.read(appReviewManagementProvider('app1')).isEmpty, isTrue);
    });

    test('永続化データがあれば復元する', () async {
      final saved = AppReviewManagement(
        connectedAppId: 'app1',
        manualStatusOverride: ReviewStatusType.approved,
        note: '復元されたメモ',
      );
      final spyContainer = ProviderContainer(
        overrides: [
          localStoreServiceProvider
              .overrideWithValue(_SpyLocalStoreService(initial: saved)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer
          .read(appReviewManagementBootstrapProvider('app1').future);

      final state = spyContainer.read(appReviewManagementProvider('app1'));
      expect(state.manualStatusOverride, ReviewStatusType.approved);
      expect(state.note, '復元されたメモ');
    });
  });
}
