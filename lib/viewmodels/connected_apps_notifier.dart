import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/connected_app.dart';
import '../models/platform_type.dart';
import '../models/user_plan.dart';
import 'service_providers.dart';

/// 登録済みアプリ一覧の状態管理（Must#5: アプリ登録・並び替え）。
/// 無料プランは2アプリまで（3本目でペイウォール、設計書 Step3.5 R④）。
class ConnectedAppsNotifier extends Notifier<List<ConnectedApp>> {
  @override
  List<ConnectedApp> build() => [];

  Future<ConnectedApp> registerApp({
    required String userId,
    required PlatformType platform,
    required String bundleIdOrPackageName,
    required String displayName,
    required String apiKey,
  }) async {
    final id = const Uuid().v4();
    await ref.read(secureStorageServiceProvider).saveApiKey(
          connectedAppId: id,
          apiKey: apiKey,
        );
    final app = ConnectedApp(
      id: id,
      userId: userId,
      platform: platform,
      bundleIdOrPackageName: bundleIdOrPackageName,
      apiKeyRef: id,
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

  /// ドッグフーディング・実機テスト用：初回起動時にデモアプリを自動登録
  /// （オンボーディング→アプリ登録フロー不要で、直接ダッシュボードからテスト開始可能）
  Future<void> initializeDemoAppsIfNeeded() async {
    if (state.isNotEmpty) {
      return; // 既に登録済みなら何もしない
    }

    // デモアプリ1: iOS（App Store Connect版 Aha Moment 管理）
    await registerApp(
      userId: 'demo_user',
      platform: PlatformType.ios,
      bundleIdOrPackageName: 'com.yourcompany.sampleios',
      displayName: 'Sample iOS App',
      apiKey: 'demo_api_key_ios_12345',
    );

    // デモアプリ2: Android（Play Console版）
    await registerApp(
      userId: 'demo_user',
      platform: PlatformType.android,
      bundleIdOrPackageName: 'com.yourcompany.sampleandroid',
      displayName: 'Sample Android App',
      apiKey: 'demo_api_key_android_67890',
    );
  }
}

final connectedAppsProvider =
    NotifierProvider<ConnectedAppsNotifier, List<ConnectedApp>>(
  ConnectedAppsNotifier.new,
);

/// 現在のユーザープラン（MVPはローカル保持のみ、Firebase Auth/Firestore連携は次フェーズ）
final userPlanProvider = StateProvider<UserPlan>((ref) => UserPlan.free);
