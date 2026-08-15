import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/l10n/gen/app_localizations.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';

/// 他の全ウィジェットテストは決定性のためlocaleを'ja'に固定しているが、
/// それだけだと「supportedLocalesにenを加えたが実は何も英語化されていない」
/// という状態を検出できない。ここではあえてlocaleを'en'に固定し、
/// 実際に英語の文言へ切り替わることを確認する（PR以前の main.dart のコメントが
/// 指摘していた「'en'を宣言しているのに実態は日本語のまま」という問題の再発防止）。
void main() {
  testWidgets('locale=enではダッシュボードが英語表示になる', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ririkan'), findsWidgets); // AppBar title
    expect(find.text('リリカン'), findsNothing);
    expect(find.text('Add App'), findsOneWidget);
    // 保存データが無いため appBootstrapProvider がデモアプリを自動投入する
    // （日本語版と同じ挙動）。デモアプリ名自体は多言語対応の対象外（固定の
    // サンプルデータ）なので、日本語UIが一切残っていないことだけ確認する。
    expect(find.text('まだ登録アプリがありません'), findsNothing);
  });

  testWidgets('locale=enでは審査状態のラベルも英語になる', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'Test App',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // MockDataService: iOSは審査中(inReview)で返る。
    expect(find.textContaining('In Review'), findsOneWidget);
  });
}
