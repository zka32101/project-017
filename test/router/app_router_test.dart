import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

import '../test_utils/fakes.dart';

/// ディープリンク（通知タップ等）で extra なしに /app-detail/:id 等へ
/// 遷移した場合の解決ロジック（_AppDetailByIdResolver等）を検証する。
/// レビューで「real branching logic を持つが0%カバレッジ」と指摘された箇所。
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<GoRouter> pumpAppAt(WidgetTester tester, String location) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(location);
    await tester.pumpAndSettle();
    return router;
  }

  group('/app-detail/:id（extraなし、ディープリンク経由）', () {
    testWidgets('登録済みアプリのidなら詳細画面が表示される', (tester) async {
      final app = await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: 'テストアプリ',
            apiKey: 'k',
          );

      await pumpAppAt(tester, '/app-detail/${app.id}');

      expect(find.text('テストアプリ'), findsWidgets); // AppBarタイトル
      expect(find.text('アプリが見つかりません'), findsNothing);
    });

    testWidgets('未登録のidなら「アプリが見つかりません」が表示される', (tester) async {
      await pumpAppAt(tester, '/app-detail/does-not-exist');

      expect(find.text('アプリが見つかりません'), findsOneWidget);
    });
  });

  group('/checklist/:id（extraなし、ディープリンク経由）', () {
    testWidgets('登録済みアプリのidならチェックリスト画面が表示される', (tester) async {
      final app = await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: 'テストアプリ',
            apiKey: 'k',
          );

      await pumpAppAt(tester, '/checklist/${app.id}');

      expect(find.text('提出前チェックリスト・テストアプリ'), findsOneWidget);
      expect(find.text('アプリが見つかりません'), findsNothing);
    });

    testWidgets('未登録のidなら「アプリが見つかりません」が表示される', (tester) async {
      await pumpAppAt(tester, '/checklist/does-not-exist');

      expect(find.text('アプリが見つかりません'), findsOneWidget);
    });
  });

  group('/export/:id（extraなし、ディープリンク経由）', () {
    testWidgets('登録済みアプリのidならエクスポート画面が表示される', (tester) async {
      final app = await container.read(connectedAppsProvider.notifier).registerApp(
            userId: 'u1',
            platform: PlatformType.ios,
            bundleIdOrPackageName: 'works.petit.app1',
            displayName: 'テストアプリ',
            apiKey: 'k',
          );

      await pumpAppAt(tester, '/export/${app.id}');

      expect(find.text('エクスポート・テストアプリ'), findsOneWidget);
      expect(find.text('アプリが見つかりません'), findsNothing);
    });

    testWidgets('未登録のidなら「アプリが見つかりません」が表示される', (tester) async {
      await pumpAppAt(tester, '/export/does-not-exist');

      expect(find.text('アプリが見つかりません'), findsOneWidget);
    });
  });
}
