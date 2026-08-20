import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/app_review_management.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/viewmodels/app_review_management_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

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
