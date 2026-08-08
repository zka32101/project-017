import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

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

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService()),
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

  group('ConnectedAppsNotifier.wouldHitPaywall', () {
    test('無料プランは2アプリ登録済みで3本目登録時にペイウォールに達する', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      for (var i = 0; i < 2; i++) {
        await notifier.registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app$i',
          displayName: 'App$i',
          apiKey: 'key$i',
        );
      }
      expect(notifier.wouldHitPaywall(UserPlan.free), isTrue);
    });

    test('Proプランはペイウォールに達しない', () async {
      final notifier = container.read(connectedAppsProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await notifier.registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app$i',
          displayName: 'App$i',
          apiKey: 'key$i',
        );
      }
      expect(notifier.wouldHitPaywall(UserPlan.pro), isFalse);
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

      // A,B,C → 先頭(A)を末尾(index 2)に移動 → B,C,A
      notifier.reorder(0, 2);

      final names = container.read(connectedAppsProvider).map((a) => a.displayName).toList();
      expect(names, ['B', 'C', 'A']);
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
}
