import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/services/widget_sync_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

/// 実機のKeychain/EncryptedSharedPreferencesに依存しないインメモリ版
/// （connected_apps_notifier_test.dart と同じパターン）。
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

/// HomeWidgetのプラットフォームチャネル呼び出しが失敗するケース（未実装のiOS
/// WidgetKit拡張、Androidでの登録漏れ等）を再現するフェイク。
class _FailingWidgetSyncService extends WidgetSyncService {
  const _FailingWidgetSyncService();

  @override
  Future<void> syncSummary({
    required int totalApps,
    required int attentionCount,
    required ConnectedApp? topAttentionApp,
  }) async =>
      throw Exception('ネイティブ側ウィジェット同期に失敗しました（テスト用）');
}

void main() {
  test('syncSummaryが失敗しても、各アプリの集計が成功していればwidgetSyncProviderはエラーにならない', () async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
        widgetSyncServiceProvider.overrideWithValue(const _FailingWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'App1',
          apiKey: 'k',
        );

    // syncSummary（ネイティブ側呼び出し）が例外を投げても、widgetSyncProvider の
    // 関数コメントが約束する「失敗しても画面表示は継続」の通り、ここまでの
    // 集計処理が無駄にならずAsyncErrorに落ちてはいけない。
    await expectLater(
      container.read(widgetSyncProvider.future),
      completes,
    );
  });
}
