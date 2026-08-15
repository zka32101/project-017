import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/connected_app.dart';
import '../models/platform_type.dart';
import '../models/user_plan.dart';
import '../services/local_store_service.dart';
import 'service_providers.dart';

/// 登録済みアプリ一覧の状態管理（Must#5: アプリ登録・並び替え）。
/// 無料プランは2アプリまで（3本目でペイウォール、設計書 Step3.5 R④）。
class ConnectedAppsNotifier extends Notifier<List<ConnectedApp>> {
  /// initializeDemoAppsIfNeeded の多重実行防止用（複数箇所から並行して
  /// 呼ばれても、実際の登録処理は1回しか走らないようにする）。
  Future<void>? _demoInitFuture;

  @override
  List<ConnectedApp> build() => [];

  Future<ConnectedApp> registerApp({
    required String userId,
    required PlatformType platform,
    required String bundleIdOrPackageName,
    required String displayName,
    required String apiKey,
    String? id,
  }) async {
    final resolvedId = id ?? const Uuid().v4();
    await ref.read(secureStorageServiceProvider).saveApiKey(
          connectedAppId: resolvedId,
          apiKey: apiKey,
        );
    final app = ConnectedApp(
      id: resolvedId,
      userId: userId,
      platform: platform,
      bundleIdOrPackageName: bundleIdOrPackageName,
      apiKeyRef: resolvedId,
      displayName: displayName,
      sortOrder: state.length,
    );
    state = [...state, app];
    await _persist();
    return app;
  }

  /// oldIndex/newIndex は ReorderableListView の onReorderItem が既に
  /// 「削除後基準」に調整済みの値を渡してくる（onReorder の手動調整は不要、Flutter SDK仕様）。
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
    await _persist();
  }

  Future<void> removeApp(String id) async {
    await ref.read(secureStorageServiceProvider).deleteApiKey(id);
    state = state.where((a) => a.id != id).toList();
    await _persist();
  }

  /// 永続化データからの復元用。APIキー本体は前回セッションで既にSecure
  /// Storageへ保存済みのため、ここではメタデータ一覧をstateへ反映するだけでよい
  /// （Secure Storageへの再書き込みは行わない）。
  void restore(List<ConnectedApp> apps) {
    state = apps;
  }

  /// プラン変更（ペイウォールでのアップグレード等）をuserPlanProviderへ反映しつつ、
  /// 永続化もあわせて行う。paywall_screen.dart等はこのメソッド経由で変更すること
  /// （userPlanProvider.notifier.state を直接書き換えると永続化されない）。
  Future<void> setPlan(UserPlan plan) async {
    ref.read(userPlanProvider.notifier).state = plan;
    await _persist();
  }

  Future<void> _persist() async {
    await ref.read(localStoreServiceProvider).save(
          LocalState(apps: state, plan: ref.read(userPlanProvider)),
        );
  }

  /// 3本目登録＝ペイウォール到達（無料プランのみ判定、KPI: app_registered_3rd）
  bool wouldHitPaywall(UserPlan plan) =>
      plan == UserPlan.free && state.length >= UserPlan.freeAppLimit;

  /// デモアプリの固定ID。乱数（uuid）にすると、状態がインメモリのみで
  /// 永続化されていない現状、起動のたびに新しいIDでデモアプリが再登録され、
  /// Secure Storage（Keychain/EncryptedSharedPreferences）に古いエントリが
  /// 際限なく残り続けてしまう。固定IDにすることで再登録時は同じキーを
  /// 上書きするだけになり、余計な秘密情報の蓄積を防ぐ。
  static const _demoIosAppId = 'demo-app-ios';
  static const _demoAndroidAppId = 'demo-app-android';

  /// ドッグフーディング・実機テスト用：初回起動時にデモアプリを自動登録
  /// （オンボーディング→アプリ登録フロー不要で、直接ダッシュボードからテスト開始可能）
  Future<void> initializeDemoAppsIfNeeded() {
    if (state.isNotEmpty) {
      return Future.value(); // 既に登録済みなら何もしない
    }
    // build() からの副作用として呼ばれるため、短時間に複数回呼ばれても
    // 登録処理は1回分の Future を共有し、デモアプリの二重登録を防ぐ。
    return _demoInitFuture ??= _seedDemoApps();
  }

  Future<void> _seedDemoApps() async {
    final registeredIds = <String>[];
    try {
      // デモアプリ1: iOS（App Store Connect版 Aha Moment 管理）
      final iosApp = await registerApp(
        id: _demoIosAppId,
        userId: 'demo_user',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'com.yourcompany.sampleios',
        displayName: 'Sample iOS App',
        apiKey: 'demo_api_key_ios_12345',
      );
      registeredIds.add(iosApp.id);

      // デモアプリ2: Android（Play Console版）
      final androidApp = await registerApp(
        id: _demoAndroidAppId,
        userId: 'demo_user',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'com.yourcompany.sampleandroid',
        displayName: 'Sample Android App',
        apiKey: 'demo_api_key_android_67890',
      );
      registeredIds.add(androidApp.id);
    } catch (_) {
      // 2件のうち片方だけ登録できた状態で終わると、initializeDemoAppsIfNeeded()の
      // 「state.isNotEmptyなら何もしない」ガードにより、以後 stateが空にならず
      // 残り1件が永久に再試行されなくなる。中途半端に登録できた分は巻き戻し、
      // 次回の呼び出しで最初からやり直せるようにする。
      for (final id in registeredIds) {
        try {
          await removeApp(id);
        } catch (_) {
          // ロールバック自体の失敗は元の例外をマスクしないよう無視する。
        }
      }
      rethrow;
    } finally {
      // 完了後にリセットしておくことで、全アプリ削除後に再度呼ばれた場合は
      // 改めて登録処理が走る（既存の「stateが空なら再セット」という仕様を維持）。
      _demoInitFuture = null;
    }
  }
}

final connectedAppsProvider =
    NotifierProvider<ConnectedAppsNotifier, List<ConnectedApp>>(
  ConnectedAppsNotifier.new,
);

/// 現在のユーザープラン（Firebase Auth/Firestore連携は次フェーズ、それまではローカル永続化のみ）。
/// 直接 state を書き換えず ConnectedAppsNotifier.setPlan() 経由で変更すること（永続化のため）。
final userPlanProvider = StateProvider<UserPlan>((ref) => UserPlan.free);

/// アプリ起動時に一度だけ実行する初期化処理。
/// 永続化データ（登録アプリ一覧・プラン）があればそれを復元し、無ければ
/// （初回起動、または永続化非対応環境）従来通りデモアプリを自動登録する。
///
/// ConnectedAppsNotifier.build() 内の暗黙的な副作用として自動発火させるのでは
/// なく、あえて独立したFutureProviderとして明示的に一度だけ待つ設計にしている。
/// build()内で自動発火する設計だと、ProviderContainerを作って即座に
/// registerApp/removeAppを呼ぶ既存の単体テスト群と非同期のタイミングが競合し、
/// テストが登録したはずのアプリが復元処理に上書きされる/されない、といった
/// 非決定的な失敗を招きかねない。DashboardScreen側で明示的にwatchすることで、
/// 通常の単体テスト（connectedAppsProviderのnotifierを直接操作するもの）は
/// このプロバイダに一切触れず、影響を受けない。
final appBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(localStoreServiceProvider);
  final saved = await store.load();
  final notifier = ref.read(connectedAppsProvider.notifier);

  if (saved != null) {
    ref.read(userPlanProvider.notifier).state = saved.plan;
    if (saved.apps.isNotEmpty) {
      notifier.restore(saved.apps);
      return;
    }
  }

  // 保存データが無い（初回起動・永続化非対応環境）か、保存された一覧が空なら
  // 従来通りデモアプリを自動登録する。デモアプリのIDは固定のため、繰り返し
  // 呼ばれてもSecure Storageに新規エントリが増え続けることはない。
  await notifier.initializeDemoAppsIfNeeded();
});
