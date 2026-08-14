import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/connected_app.dart';
import '../models/platform_type.dart';
import '../models/user_plan.dart';
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
    return app;
  }

  /// oldIndex/newIndex は ReorderableListView の onReorderItem が既に
  /// 「削除後基準」に調整済みの値を渡してくる（onReorder の手動調整は不要、Flutter SDK仕様）。
  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
  }

  Future<void> removeApp(String id) async {
    await ref.read(secureStorageServiceProvider).deleteApiKey(id);
    state = state.where((a) => a.id != id).toList();
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

/// 現在のユーザープラン（MVPはローカル保持のみ、Firebase Auth/Firestore連携は次フェーズ）
final userPlanProvider = StateProvider<UserPlan>((ref) => UserPlan.free);
