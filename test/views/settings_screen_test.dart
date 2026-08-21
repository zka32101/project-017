import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/l10n/gen/app_localizations.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/export_service.dart';
import 'package:ririkan/services/revenue_cat_oauth_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/export_provider.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';
import 'package:ririkan/views/settings/settings_screen.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

/// exportAppRoster()の戻り値を固定できるフェイク(ファイルI/O・Shareを
/// 一切行わないため、testWidgets環境でも安全に成功/失敗の両方を再現できる)。
class _FixedExportService extends ExportService {
  const _FixedExportService(this.rosterPath);

  final String? rosterPath;

  @override
  Future<String?> exportAppRoster(List<ConnectedApp> apps) async => rosterPath;
}

class _FixedWebAuthLauncher implements WebAuthLauncher {
  _FixedWebAuthLauncher();

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) async {
    final state = Uri.parse(url).queryParameters['state'];
    return 'ririkan://revenuecat-oauth-callback?code=c&state=$state';
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  testWidgets('削除アイコンをタップ→確認ダイアログで「削除」を選ぶとアプリが一覧・stateから消える',
      (tester) async {
    // ウィジェットをpumpする前にコンテナへ直接登録しておくことで、
    // ダッシュボードの appBootstrapProvider が走る時点で
    // state.isNotEmpty となり、デモアプリの自動投入をスキップさせる
    // （initializeDemoAppsIfNeeded の既存ガード）。
    final app = await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: '削除対象アプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('削除対象アプリ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // 確認ダイアログが出た時点ではまだ削除されていない。
    expect(find.text('このアプリを削除しますか？'), findsOneWidget);
    expect(find.text('削除対象アプリ'), findsOneWidget);

    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('削除対象アプリ'), findsNothing);
    expect(
      container.read(connectedAppsProvider).where((a) => a.id == app.id),
      isEmpty,
    );
  });

  testWidgets('削除確認ダイアログで「キャンセル」を選ぶとアプリは消えない', (tester) async {
    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: '削除対象アプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('削除対象アプリ'), findsOneWidget);
    expect(container.read(connectedAppsProvider), hasLength(1));
  });

  testWidgets('登録済みAPIキーは全文表示されず、末尾4文字だけのマスク表示になる',
      (tester) async {
    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'キー表示テストアプリ',
          apiKey: 'test-api-key-1234',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('APIキー: ••••••••1234'), findsOneWidget);
    // キー本体(先頭側)がそのまま画面に出ていないこと。
    expect(find.textContaining('test-api-key-1234'), findsNothing);
  });

  testWidgets('RevenueCat未接続時は「接続する」ボタンが表示され、タップで入力フォームが開く',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('未接続（売上・DL数はサンプルデータのまま）'), findsOneWidget);
    expect(find.text('接続する'), findsOneWidget);
    // フォームはまだ開いていない。
    expect(find.text('Client ID'), findsNothing);

    await tester.tap(find.text('接続する'));
    await tester.pumpAndSettle();

    expect(find.text('Client ID'), findsOneWidget);
    expect(find.text('Client Secret'), findsOneWidget);
  });

  testWidgets('RevenueCat接続済みなら「接続済み」表示になり、「切断」で未接続に戻る',
      (tester) async {
    final storage = FakeSecureStorageService();
    final oauth = RevenueCatOAuthService(
      secureStorageService: storage,
      webAuthLauncher: _FixedWebAuthLauncher(),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'access_token': 'at', 'refresh_token': 'rt', 'expires_in': 3600}),
          200,
        );
      }),
    );
    // 事前に接続済みの状態を作っておく(ウィジェットからは同じインスタンスを
    // overrideWithValueで注入するため、ここでの接続がそのまま反映される)。
    await oauth.connect(clientId: 'cid', clientSecret: 'csecret');

    final connectedContainer = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        revenueCatOAuthServiceProvider.overrideWithValue(oauth),
      ],
    );
    addTearDown(connectedContainer.dispose);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: connectedContainer,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('接続済み'), findsOneWidget);
    expect(find.text('切断'), findsOneWidget);

    await tester.tap(find.text('切断'));
    await tester.pumpAndSettle();

    expect(find.text('未接続（売上・DL数はサンプルデータのまま）'), findsOneWidget);
  });

  group('登録アプリ一覧のCSVエクスポート（大量アプリ管理）', () {
    testWidgets('登録アプリが1件以上あればエクスポートアイコンが表示される', (tester) async {
      await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: 'テストアプリ',
            apiKey: 'k',
          );

      final router = buildAppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapWithLocalizedRouter(router),
        ),
      );
      router.go('/settings');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    });

    testWidgets('登録アプリが無ければエクスポートアイコンは表示されない', (tester) async {
      // GoRouter経由(initialLocation: /dashboard)で開くと、DashboardScreenの
      // appBootstrapProviderが空のapps一覧を見てデモアプリを自動投入してしまい
      // 「登録アプリ0件」の状態を検証できない。SettingsScreenを直接pumpして
      // このシナリオを再現する。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.ios_share_outlined), findsNothing);
    });

    testWidgets('書き出しに失敗した場合はエラーメッセージが表示される', (tester) async {
      final failingContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
          widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
          // nullを返す=失敗を再現(ファイルI/O・Shareの実プラットフォームチャネルには
          // 一切触れないため、testWidgets環境でも安全)。
          exportServiceProvider.overrideWithValue(const _FixedExportService(null)),
        ],
      );
      addTearDown(failingContainer.dispose);
      await failingContainer.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: 'テストアプリ',
            apiKey: 'k',
          );

      final router = buildAppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: failingContainer,
          child: wrapWithLocalizedRouter(router),
        ),
      );
      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();

      expect(find.text('書き出しに失敗しました'), findsOneWidget);
    });
  });

  testWidgets('無料プラン(広告あり)の場合、「広告を消す」ボタンからペイウォールへ遷移できる',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('広告あり'), findsOneWidget);
    expect(find.text('広告を消す'), findsOneWidget);

    await tester.tap(find.text('広告を消す'));
    await tester.pumpAndSettle();

    expect(find.text('広告を消しませんか？'), findsOneWidget);
  });
}
