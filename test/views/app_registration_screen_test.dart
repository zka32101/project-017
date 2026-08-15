import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';

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

  Future<void> pumpRegistrationScreen(WidgetTester tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // initialLocation は /dashboard のため、遷移前にデモアプリ自動登録
    // （appBootstrapProvider）の非同期処理が裏で走り出す。pumpAndSettle で
    // その完了まで待ってから /app-registration へ遷移する。
    router.go('/app-registration');
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitButton = find.text('登録して初回スキャンを開始');
    // 画面は SingleChildScrollView 内にあり、デフォルトのテスト画面サイズでは
    // ボタンが画面外にはみ出すため、タップ前にスクロールして可視化する。
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
  }

  testWidgets('未入力のまま送信すると「すべての項目を入力してください」が表示され、登録されない',
      (tester) async {
    await pumpRegistrationScreen(tester);
    final countBefore = container.read(connectedAppsProvider).length;

    await tapSubmit(tester);
    await tester.pump(); // SnackBarのアニメーション開始分だけpump（pumpAndSettleだと消えてしまう）

    expect(find.text('すべての項目を入力してください'), findsOneWidget);
    // デモアプリ自動登録（initialLocation経由）以外に新規登録が発生していないこと。
    expect(container.read(connectedAppsProvider), hasLength(countBefore));
  });

  testWidgets('全項目入力して送信するとアプリが登録され、初回スキャン経由でダッシュボードに遷移する',
      (tester) async {
    await pumpRegistrationScreen(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3)); // 表示名・Bundle ID・APIキーの3つ
    await tester.enterText(fields.at(0), 'テスト用アプリ');
    await tester.enterText(fields.at(1), 'works.petit.testapp');
    await tester.enterText(fields.at(2), 'test-api-key');
    await tester.pump();

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    // 初回スキャン画面を経由し、成功すれば自動的にダッシュボードへ戻る
    // （initialScanProviderがAsyncDataになった時点でcontext.go('/dashboard')）。
    expect(find.text('テスト用アプリ'), findsWidgets);

    final registered = container
        .read(connectedAppsProvider)
        .where((a) => a.displayName == 'テスト用アプリ');
    expect(registered, hasLength(1));
    expect(registered.first.bundleIdOrPackageName, 'works.petit.testapp');
    expect(registered.first.hasApiKeyRegistered, isTrue);
  });
}
