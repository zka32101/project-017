// リリカン起動スモークテスト
// ドッグフーディング・実機テスト用に initialLocation を /dashboard に変更したため、
// 起動直後はダッシュボード画面が表示される（デモアプリが自動初期化される）。
//
// SecureStorageService(flutter_secure_storage)・LocalStoreService(path_provider)・
// WidgetSyncService(home_widget) はいずれもプラットフォームチャネル経由の実装で、
// flutter test 環境では未モックのMethodChannel呼び出しが例外になる
// （実機/実OS上でのみ動作するプラグインのため）。他の単体テストと同様、
// これらをインメモリ/no-opのフェイクに差し替えてから起動する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ririkan/main.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/services/widget_sync_service.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

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

  @override
  Future<void> deleteChecklist(String connectedAppId) async {}
}

class _FakeWidgetSyncService extends WidgetSyncService {
  const _FakeWidgetSyncService();

  @override
  Future<void> syncSummary({
    required int totalApps,
    required int attentionCount,
    required ConnectedApp? topAttentionApp,
  }) async {}
}

void main() {
  testWidgets('起動するとダッシュボードが表示される（デモアプリ自動初期化）',
      (WidgetTester tester) async {
    // RirikanApp（本物）は日本語＋英語の両方をsupportedLocalesに含むため、
    // テスト実行環境のシステムロケール解決に依存させないよう'ja'に固定する
    // （他のテストではラッパー側でlocale:を明示できるが、ここではRirikanAppを
    // そのままpumpするため、テストバインディング側のロケールを上書きする）。
    tester.platformDispatcher.localeTestValue = const Locale('ja');
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(const _FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const _FakeWidgetSyncService()),
        ],
        child: const RirikanApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ダッシュボード画面の表示確認（デモアプリが自動初期化される）
    expect(find.text('リリカン'), findsWidgets); // AppBar のタイトル
    expect(find.text('Sample iOS App'), findsOneWidget); // デモアプリ1: iOS
    expect(find.text('Sample Android App'), findsOneWidget); // デモアプリ2: Android
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget); // 設定ボタン
  });
}
