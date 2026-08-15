import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/viewmodels/checklist_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

/// setResult内部の永続化(saveChecklist)がpath_providerのプラットフォームチャネルに
/// 触れないようにするフェイク。このファイルはtestWidgetsではなくtest
/// （Flutter bindingを初期化しないプレーンなDartテスト）のため。
class _FakeLocalStoreService extends LocalStoreService {
  const _FakeLocalStoreService();

  @override
  Future<LocalState?> load() async => null;

  @override
  Future<void> save(LocalState state) async {}

  @override
  Future<List<SubmissionChecklistItem>?> loadChecklist(
    String connectedAppId,
  ) async =>
      null;

  @override
  Future<void> saveChecklist(
    String connectedAppId,
    List<SubmissionChecklistItem> items,
  ) async {}
}

/// load()/loadChecklist()の戻り値を差し込め、saveChecklist()の呼び出しを
/// 記録できるフェイク。checklistBootstrapProviderとsetResultの永続化検証に使う。
class _SpyLocalStoreService extends LocalStoreService {
  _SpyLocalStoreService({List<SubmissionChecklistItem>? initialChecklist})
      : _storedChecklist = initialChecklist;

  List<SubmissionChecklistItem>? _storedChecklist;
  int saveChecklistCallCount = 0;

  @override
  Future<LocalState?> load() async => null;

  @override
  Future<void> save(LocalState state) async {}

  @override
  Future<List<SubmissionChecklistItem>?> loadChecklist(
    String connectedAppId,
  ) async =>
      _storedChecklist;

  @override
  Future<void> saveChecklist(
    String connectedAppId,
    List<SubmissionChecklistItem> items,
  ) async {
    _storedChecklist = items;
    saveChecklistCallCount++;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
      ],
    );
  });
  tearDown(() => container.dispose());

  group('ChecklistNotifier', () {
    test('初期状態は固定マスタ全項目がuncheckedで生成される', () {
      final items = container.read(checklistProvider('app1'));
      expect(items.length, ChecklistItemKey.values.length);
      expect(items.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });

    test('setResultで該当項目のみ結果が更新される', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final checkedAt = DateTime(2026, 8, 5);
      notifier.setResult(
        ChecklistItemKey.privacyPolicyUrl,
        ChecklistResult.pass,
        checkedAt,
      );

      final items = container.read(checklistProvider('app1'));
      final target = items.firstWhere(
        (i) => i.itemKey == ChecklistItemKey.privacyPolicyUrl,
      );
      expect(target.result, ChecklistResult.pass);
      expect(target.checkedAt, checkedAt);

      final others = items.where(
        (i) => i.itemKey != ChecklistItemKey.privacyPolicyUrl,
      );
      expect(others.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });

    test('全項目passでallPassedがtrueになる', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final now = DateTime(2026, 8, 5);
      for (final key in ChecklistItemKey.values) {
        notifier.setResult(key, ChecklistResult.pass, now);
      }
      expect(notifier.allPassed, isTrue);
      expect(notifier.passCount, ChecklistItemKey.values.length);
    });

    test('1件でも未合格ならallPassedはfalse', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final now = DateTime(2026, 8, 5);
      for (final key in ChecklistItemKey.values) {
        notifier.setResult(key, ChecklistResult.pass, now);
      }
      notifier.setResult(
        ChecklistItemKey.values.first,
        ChecklistResult.fail,
        now,
      );
      expect(notifier.allPassed, isFalse);
    });

    test('別のconnectedAppIdは独立した状態を持つ', () {
      final notifierA = container.read(checklistProvider('appA').notifier);
      notifierA.setResult(
        ChecklistItemKey.ageRating,
        ChecklistResult.pass,
        DateTime(2026, 8, 5),
      );

      final itemsB = container.read(checklistProvider('appB'));
      expect(itemsB.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });
  });

  group('ChecklistNotifier.setResult 永続化', () {
    test('setResultのたびにsaveChecklistが呼ばれる', () async {
      final spy = _SpyLocalStoreService();
      final spyContainer = ProviderContainer(
        overrides: [localStoreServiceProvider.overrideWithValue(spy)],
      );
      addTearDown(spyContainer.dispose);

      final notifier = spyContainer.read(checklistProvider('app1').notifier);
      await notifier.setResult(
        ChecklistItemKey.privacyPolicyUrl,
        ChecklistResult.pass,
        DateTime(2026, 8, 5),
      );

      expect(spy.saveChecklistCallCount, 1);
    });
  });

  group('checklistBootstrapProvider', () {
    test('永続化データが無ければ初期状態（全項目unchecked）のまま', () async {
      final spyContainer = ProviderContainer(
        overrides: [
          localStoreServiceProvider.overrideWithValue(_SpyLocalStoreService()),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(checklistBootstrapProvider('app1').future);

      final items = spyContainer.read(checklistProvider('app1'));
      expect(items.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });

    test('永続化データがあれば該当項目の結果を復元する', () async {
      final checkedAt = DateTime(2026, 8, 5);
      final saved = [
        SubmissionChecklistItem(
          id: 'app1_${ChecklistItemKey.privacyPolicyUrl.name}',
          connectedAppId: 'app1',
          itemKey: ChecklistItemKey.privacyPolicyUrl,
          checkedAt: checkedAt,
          result: ChecklistResult.pass,
        ),
      ];
      final spyContainer = ProviderContainer(
        overrides: [
          localStoreServiceProvider
              .overrideWithValue(_SpyLocalStoreService(initialChecklist: saved)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(checklistBootstrapProvider('app1').future);

      final items = spyContainer.read(checklistProvider('app1'));
      expect(items.length, ChecklistItemKey.values.length);
      final restored = items.firstWhere(
        (i) => i.itemKey == ChecklistItemKey.privacyPolicyUrl,
      );
      expect(restored.result, ChecklistResult.pass);
      expect(restored.checkedAt, checkedAt);

      // 復元データに含まれない他の項目は初期状態（unchecked）のまま欠落しない。
      final others =
          items.where((i) => i.itemKey != ChecklistItemKey.privacyPolicyUrl);
      expect(others.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });
  });
}
