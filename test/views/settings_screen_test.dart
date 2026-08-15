import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

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
}
