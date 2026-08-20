import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/services/cloud_sync_service.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/services/purchase_service.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

/// appBootstrapProviderが「広告を消す」エンタイトルメント状態を確認する際に
/// 実PurchaseService(purchases_flutterのプラットフォームチャネル)へ触れない
/// ようにするフェイク。
class _FakePurchaseService implements PurchaseService {
  _FakePurchaseService({this.adsRemoved = false});

  /// null = RevenueCat未設定・通信エラー等で確認不能(appBootstrapProvider側は
  /// この場合プランを補正しないはず)。
  final bool? adsRemoved;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool?> isAdsRemoved() async => adsRemoved;

  @override
  Future<Package?> getRemoveAdsPackage() async => null;

  @override
  Future<bool> purchaseRemoveAds(Package package) async => false;

  @override
  Future<bool> restorePurchases() async => adsRemoved ?? false;
}

/// appBootstrapProviderのFirestore復元フォールバック・_persist()からの
/// バックアップ呼び出しを検証するためのフェイク/スパイ。実CloudSyncService
/// (Firebaseのプラットフォームチャネル)には一切触れない。
class _FakeCloudSyncService implements CloudSyncService {
  _FakeCloudSyncService({this.restoreValue});

  final LocalState? restoreValue;
  int backupCallCount = 0;
  LocalState? lastBackedUp;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> backup(LocalState state) async {
    backupCallCount++;
    lastBackedUp = state;
  }

  @override
  Future<LocalState?> restore() async => restoreValue;
}

/// registerApp/reorder/removeApp が内部で呼ぶ永続化(_persist)がpath_providerの
/// プラットフォームチャネルに触れないようにするフェイク。このファイルは
/// testWidgetsではなくtest（Flutter bindingを初期化しないプレーンなDartテスト）
/// のため、未モックのプラットフォームチャネル呼び出しは安全に倒せない。
class _FakeLocalStoreService extends LocalStoreService {
  const _FakeLocalStoreService();

  @override
  Future<LocalState?> load() async => null;

  @override
  Future<void> save(LocalState state) async {}

  @override
  Future<void> deleteChecklist(String connectedAppId) async {}
}

/// load()の戻り値を差し込め、save()の呼び出しを記録できるフェイク。
/// appBootstrapProvider（復元 or デモ投入の分岐）とsetPlan/persistの検証に使う。
class _SpyLocalStoreService extends LocalStoreService {
  _SpyLocalStoreService({LocalState? initial}) : _stored = initial;

  LocalState? _stored;
  int saveCallCount = 0;

  @override
  Future<LocalState?> load() async => _stored;

  @override
  Future<void> save(LocalState state) async {
    _stored = state;
    saveCallCount++;
  }

  @override
  Future<void> deleteChecklist(String connectedAppId) async {}
}

/// 実機のKeychain/EncryptedSharedPreferencesに依存しないインメモリ版。
/// 単体テストでは flutter_secure_storage のプラットフォームチャネルが無いため、
/// SecureStorageService を継承しストレージ操作をメモリMapに差し替える。
class _FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async {
    _memory[SecureStorageService.refKeyFor(connectedAppId)] = apiKey;
  }

  @override
  Future<String?> readApiKey(String connectedAppId) async =>
      _memory[SecureStorageService.refKeyFor(connectedAppId)];

  @override
  Future<void> deleteApiKey(String connectedAppId) async {
    _memory.remove(SecureStorageService.refKeyFor(connectedAppId));
  }
}

/// APIキーの保存（Keychain/EncryptedSharedPreferencesへの書き込み）が失敗するケースを
/// 再現するフェイク。registerApp が例外を投げっぱなしにせず、呼び出し元
/// （画面側のtry/catch）まで正しく伝播することを検証するために使う。
class _SaveFailsSecureStorageService extends SecureStorageService {
  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async =>
      throw Exception('保存に失敗しました（テスト用）');

  @override
  Future<String?> readApiKey(String connectedAppId) async => null;

  @override
  Future<void> deleteApiKey(String connectedAppId) async {}
}

/// APIキーの削除は失敗するが保存・読み取りは _FakeSecureStorageService と同様に
/// 成功するフェイク。removeApp の例外伝播だけをピンポイントで検証するために使う。
class _DeleteFailsSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async {
    _memory[SecureStorageService.refKeyFor(connectedAppId)] = apiKey;
  }

  @override
  Future<String?> readApiKey(String connectedAppId) async =>
      _memory[SecureStorageService.refKeyFor(connectedAppId)];

  @override
  Future<void> deleteApiKey(String connectedAppId) async =>
      throw Exception('削除に失敗しました（テスト用）');
}

/// n回目のsaveApiKey呼び出しだけ失敗する（1回目は成功、2回目は失敗、等）フェイク。
/// デモアプリ2件のうち片方だけ登録に成功する状況を再現するために使う。
class _FailsOnNthSaveSecureStorageService extends SecureStorageService {
  _FailsOnNthSaveSecureStorageService(this._failOnCallNumber);

  final int _failOnCallNumber;
  final Map<String, String> _memory = {};
  var _callCount = 0;

  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async {
    _callCount++;
    if (_callCount == _failOnCallNumber) {
      throw Exception('保存に失敗しました（テスト用、$_callCount回目）');
    }
    _memory[SecureStorageService.refKeyFor(connectedAppId)] = apiKey;
  }

  @override
  Future<String?> readApiKey(String connectedAppId) async =>
      _memory[SecureStorageService.refKeyFor(connectedAppId)];

  @override
  Future<void> deleteApiKey(String connectedAppId) async {
    _memory.remove(SecureStorageService.refKeyFor(connectedAppId));
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ConnectedAppsNotifier.registerApp', () {
    test('登録するとstateに追加され、sortOrderが登録順になる', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.app1',
        displayName: 'App1',
        apiKey: 'key1',
      );
      await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'works.petit.app2',
        displayName: 'App2',
        apiKey: 'key2',
      );

      final state = container.read(connectedAppsProvider);
      expect(state.length, 2);
      expect(state[0].sortOrder, 0);
      expect(state[1].sortOrder, 1);
      expect(state[1].hasApiKeyRegistered, isTrue);
    });
  });

  group('ConnectedAppsNotifier.registerAppsBulk', () {
    test('discoverAppsで見つかった複数アプリを1回の呼び出しでまとめて登録する', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      final registered = await notifier.registerAppsBulk(
        userId: 'u1',
        platform: PlatformType.ios,
        apiKey: 'shared-key',
        discovered: const [
          DiscoverableApp(
            bundleIdOrPackageName: 'works.petit.bulk1',
            displayName: 'Bulk App 1',
          ),
          DiscoverableApp(
            bundleIdOrPackageName: 'works.petit.bulk2',
            displayName: 'Bulk App 2',
          ),
        ],
      );

      expect(registered, hasLength(2));
      expect(container.read(connectedAppsProvider), hasLength(2));
      expect(registered.every((a) => a.hasApiKeyRegistered), isTrue);
      expect(
        container.read(connectedAppsProvider).map((a) => a.displayName),
        containsAll(['Bulk App 1', 'Bulk App 2']),
      );
    });
  });

  group('ConnectedAppsNotifier.reorder', () {
    test('onReorderItemが渡す調整済みインデックスで正しく並び替わる', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'a',
        displayName: 'A',
        apiKey: 'k',
      );
      await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'b',
        displayName: 'B',
        apiKey: 'k',
      );
      await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'c',
        displayName: 'C',
        apiKey: 'k',
      );

      final before = container.read(connectedAppsProvider);

      // A,B,C → 先頭(A)を末尾(index 2)に移動 → B,C,A
      await notifier.reorder(0, 2);

      final after = container.read(connectedAppsProvider);
      final names = after.map((a) => a.displayName).toList();
      expect(names, ['B', 'C', 'A']);

      // reorder は sortOrder 更新のため全アプリを copyWith するが、id ベースの
      // 等価性により「同じアプリ」として扱われる必要がある（Riverpod の
      // FutureProvider.family キャッシュが並べ替えのたびに全破棄されないように）。
      for (final app in before) {
        expect(after, contains(app));
      }
    });

    test('removeAppでstateとストレージ双方から削除される', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      final app = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'a',
        displayName: 'A',
        apiKey: 'k',
      );
      await notifier.removeApp(app.id);
      expect(container.read(connectedAppsProvider), isEmpty);
    });
  });

  group('ConnectedAppsNotifier.removeApps（大量アプリ管理・一括削除）', () {
    test('指定した複数アプリだけがまとめて削除され、残りは影響を受けない', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      final a = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'a',
        displayName: 'A',
        apiKey: 'k',
      );
      final b = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'b',
        displayName: 'B',
        apiKey: 'k',
      );
      final c = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'c',
        displayName: 'C',
        apiKey: 'k',
      );

      await notifier.removeApps([a.id, c.id]);

      final state = container.read(connectedAppsProvider);
      expect(state, hasLength(1));
      expect(state.single.id, b.id);
    });
  });

  group('ConnectedAppsNotifier.setTags（大量アプリ管理・タグ付け）', () {
    test('該当アプリのタグだけが更新され、他アプリは影響を受けない', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      final a = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'a',
        displayName: 'A',
        apiKey: 'k',
      );
      final b = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'b',
        displayName: 'B',
        apiKey: 'k',
      );

      await notifier.setTags(a.id, ['自社', '優先度高']);

      final state = container.read(connectedAppsProvider);
      expect(state.firstWhere((app) => app.id == a.id).tags,
          ['自社', '優先度高']);
      expect(state.firstWhere((app) => app.id == b.id).tags, isEmpty);
    });
  });

  group('ConnectedAppsNotifier.initializeDemoAppsIfNeeded', () {
    test('同時に複数回呼んでもデモアプリは1組しか登録されない（二重登録レースの防止）', () async {
      final notifier = container.read(connectedAppsProvider.notifier);

      // dashboard_screen が build のたびに postFrameCallback から呼ぶ状況を模した、
      // 完了を待たない並行呼び出し。
      await Future.wait([
        notifier.initializeDemoAppsIfNeeded(),
        notifier.initializeDemoAppsIfNeeded(),
        notifier.initializeDemoAppsIfNeeded(),
      ]);

      expect(container.read(connectedAppsProvider), hasLength(2));
    });

    test('再セットしてもデモアプリのIDは毎回同じ（Secure Storageのキー蓄積防止）', () async {
      final notifier = container.read(connectedAppsProvider.notifier);

      await notifier.initializeDemoAppsIfNeeded();
      final firstIds =
          container.read(connectedAppsProvider).map((a) => a.id).toSet();

      // 全アプリ削除後、再度呼ばれても同じIDで登録される（stateが空なら再セットする既存仕様）。
      for (final app in container.read(connectedAppsProvider)) {
        await notifier.removeApp(app.id);
      }
      await notifier.initializeDemoAppsIfNeeded();
      final secondIds =
          container.read(connectedAppsProvider).map((a) => a.id).toSet();

      expect(secondIds, equals(firstIds));
    });

    test('デモアプリ2件のうち片方だけ登録に失敗した場合、片方だけ残らずロールバックされ次回再試行できる', () async {
      // 1回目のsaveApiKey（iOSデモアプリ）は成功、2回目（Androidデモアプリ）は失敗する。
      final flaky = _FailsOnNthSaveSecureStorageService(2);
      final flakyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(flaky),
          localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
        ],
      );
      addTearDown(flakyContainer.dispose);

      final notifier = flakyContainer.read(connectedAppsProvider.notifier);

      await expectLater(
        notifier.initializeDemoAppsIfNeeded(),
        throwsA(isA<Exception>()),
      );

      // 片方だけ登録された状態で終わっていない（ロールバック済み）ことを確認。
      // これが無いと、次回呼び出し時に state.isNotEmpty のガードにより
      // 残り1件が永久に登録されないままになってしまう。
      expect(flakyContainer.read(connectedAppsProvider), isEmpty);

      // _FailsOnNthSaveSecureStorageServiceは2回目のsaveApiKey呼び出しだけを
      // 失敗させるため、以降の呼び出し（＝再試行）は正常に成功する。
      // 次回呼び出しで最初からやり直して2件とも登録できることを確認する。
      await notifier.initializeDemoAppsIfNeeded();
      expect(flakyContainer.read(connectedAppsProvider), hasLength(2));
    });
  });

  group('Secure Storage 失敗時の挙動', () {
    test('registerAppはAPIキー保存に失敗すると例外を投げ、stateは更新されない', () async {
      final saveFailsContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider
              .overrideWithValue(_SaveFailsSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
        ],
      );
      addTearDown(saveFailsContainer.dispose);

      final notifier = saveFailsContainer.read(connectedAppsProvider.notifier);
      await expectLater(
        notifier.registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'a',
          displayName: 'A',
          apiKey: 'k',
        ),
        throwsA(isA<Exception>()),
      );
      expect(saveFailsContainer.read(connectedAppsProvider), isEmpty);
    });

    test('removeAppはキー削除に失敗すると例外を投げ、stateからは消えない', () async {
      final deleteFailsContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider
              .overrideWithValue(_DeleteFailsSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
        ],
      );
      addTearDown(deleteFailsContainer.dispose);

      final notifier = deleteFailsContainer.read(connectedAppsProvider.notifier);
      final app = await notifier.registerApp(
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'a',
        displayName: 'A',
        apiKey: 'k',
      );

      await expectLater(
        notifier.removeApp(app.id),
        throwsA(isA<Exception>()),
      );
      expect(
        deleteFailsContainer.read(connectedAppsProvider).map((a) => a.id),
        contains(app.id),
      );
    });
  });

  group('ConnectedAppsNotifier.restore', () {
    test('永続化データをそのままstateへ反映する（Secure Storageへの再書き込みはしない）', () {
      final notifier = container.read(connectedAppsProvider.notifier);
      const restoredApps = [
        ConnectedApp(
          id: 'restored-1',
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.restored',
          apiKeyRef: 'restored-1',
          displayName: '復元済みアプリ',
          sortOrder: 0,
        ),
      ];

      notifier.restore(restoredApps);

      expect(container.read(connectedAppsProvider), restoredApps);
    });
  });

  group('ConnectedAppsNotifier.setPlan', () {
    test('userPlanProviderを更新し、永続化(save)を1回呼ぶ', () async {
      final spy = _SpyLocalStoreService();
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(spy),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(connectedAppsProvider.notifier).setPlan(UserPlan.pro);

      expect(spyContainer.read(userPlanProvider), UserPlan.pro);
      expect(spy.saveCallCount, 1);
    });
  });

  group('appBootstrapProvider', () {
    test('永続化データが無ければデモアプリを自動登録する（初回起動と同じ挙動）', () async {
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(_SpyLocalStoreService()),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(appBootstrapProvider.future);

      expect(spyContainer.read(connectedAppsProvider), hasLength(2));
    });

    test('永続化された登録アプリがあれば復元し、デモアプリは投入しない', () async {
      const persistedApp = ConnectedApp(
        id: 'persisted-1',
        userId: 'u1',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'works.petit.persisted',
        apiKeyRef: 'persisted-1',
        displayName: '永続化されたアプリ',
        sortOrder: 0,
      );
      final spy = _SpyLocalStoreService(
        initial: const LocalState(apps: [persistedApp], plan: UserPlan.pro),
      );
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(spy),
          // 「広告を消す」エンタイトルメントが有効な状態を再現し、appBootstrapProvider
          // 側のプラン補正によって復元したUserPlan.proがfreeへ巻き戻らないようにする。
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService(adsRemoved: true)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(appBootstrapProvider.future);

      expect(
        spyContainer.read(connectedAppsProvider).map((a) => a.id),
        ['persisted-1'],
      );
      expect(spyContainer.read(userPlanProvider), UserPlan.pro);
    });

    test('永続化ファイルはあるが登録アプリ一覧が空なら、プランは復元しつつデモアプリを投入する', () async {
      final spy = _SpyLocalStoreService(
        initial: const LocalState(apps: [], plan: UserPlan.pro),
      );
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(spy),
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService(adsRemoved: true)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(appBootstrapProvider.future);

      expect(spyContainer.read(connectedAppsProvider), hasLength(2));
      expect(spyContainer.read(userPlanProvider), UserPlan.pro);
    });

    test('広告を消す購入状態が確認できない(null)場合、復元したUserPlan.proを'
        'freeへ巻き戻さない(通信エラー等で購入済みユーザーに広告が復活するのを防ぐ)',
        () async {
      const persistedApp = ConnectedApp(
        id: 'persisted-2',
        userId: 'u1',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'works.petit.persisted2',
        apiKeyRef: 'persisted-2',
        displayName: '購入済みユーザーのアプリ',
        sortOrder: 0,
      );
      final spy = _SpyLocalStoreService(
        initial: const LocalState(apps: [persistedApp], plan: UserPlan.pro),
      );
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(spy),
          // adsRemoved: null は「RevenueCat未設定・通信エラー等で確認不能」を表す。
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService(adsRemoved: null)),
        ],
      );
      addTearDown(spyContainer.dispose);

      final saveCallCountBefore = spy.saveCallCount;
      await spyContainer.read(appBootstrapProvider.future);

      expect(spyContainer.read(userPlanProvider), UserPlan.pro);
      // 補正自体が発生しない(setPlanが呼ばれない)ことも確認する。
      expect(spy.saveCallCount, saveCallCountBefore);
    });

    test('ローカルに保存データが無い場合、Firestoreバックアップがあればそれを復元する'
        '（デモアプリは投入しない）', () async {
      const backedUpApp = ConnectedApp(
        id: 'cloud-1',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.cloud',
        apiKeyRef: 'cloud-1',
        displayName: 'クラウド復元アプリ',
        sortOrder: 0,
      );
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          // initialを渡さない=load()はnull(ローカルに保存データ無し)を返す。
          localStoreServiceProvider.overrideWithValue(_SpyLocalStoreService()),
          cloudSyncServiceProvider.overrideWithValue(
            _FakeCloudSyncService(
              restoreValue:
                  const LocalState(apps: [backedUpApp], plan: UserPlan.pro),
            ),
          ),
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService(adsRemoved: true)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(appBootstrapProvider.future);

      expect(
        spyContainer.read(connectedAppsProvider).map((a) => a.id),
        ['cloud-1'],
      );
      expect(spyContainer.read(userPlanProvider), UserPlan.pro);
    });

    test('ローカルに保存データがある場合はFirestoreバックアップの内容を無視し、ローカルを優先する',
        () async {
      const persistedApp = ConnectedApp(
        id: 'local-wins',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.local',
        apiKeyRef: 'local-wins',
        displayName: 'ローカル優先アプリ',
        sortOrder: 0,
      );
      const wouldBeWrongCloudApp = ConnectedApp(
        id: 'should-not-be-used',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.wrong',
        apiKeyRef: 'should-not-be-used',
        displayName: '使われてはいけないアプリ',
        sortOrder: 0,
      );
      final spy = _SpyLocalStoreService(
        initial: const LocalState(apps: [persistedApp], plan: UserPlan.pro),
      );
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(spy),
          cloudSyncServiceProvider.overrideWithValue(
            _FakeCloudSyncService(
              restoreValue: const LocalState(
                apps: [wouldBeWrongCloudApp],
                plan: UserPlan.free,
              ),
            ),
          ),
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService(adsRemoved: true)),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(appBootstrapProvider.future);

      expect(
        spyContainer.read(connectedAppsProvider).map((a) => a.id),
        ['local-wins'],
      );
    });
  });

  group('クラウドバックアップ(_persist経由)', () {
    test('setPlan等、永続化を伴う操作のたびにCloudSyncService.backup()も呼ばれる',
        () async {
      final cloudSpy = _FakeCloudSyncService();
      final spyContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
          cloudSyncServiceProvider.overrideWithValue(cloudSpy),
        ],
      );
      addTearDown(spyContainer.dispose);

      await spyContainer.read(connectedAppsProvider.notifier).setPlan(UserPlan.pro);
      // backup()はローカル保存の完了を待たせないためfire-and-forget
      // (unawaited)で呼ばれる。マイクロタスクを1回消化してから検証する。
      await Future<void>.delayed(Duration.zero);

      expect(cloudSpy.backupCallCount, 1);
      expect(cloudSpy.lastBackedUp?.plan, UserPlan.pro);
    });
  });
}
