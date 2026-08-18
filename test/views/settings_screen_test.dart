import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/revenue_cat_oauth_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

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

  testWidgets('削除アイコンをタップするとアプリが一覧・stateから消える', (tester) async {
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

    expect(find.text('削除対象アプリ'), findsNothing);
    expect(
      container.read(connectedAppsProvider).where((a) => a.id == app.id),
      isEmpty,
    );
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
