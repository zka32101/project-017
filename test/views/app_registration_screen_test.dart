import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

/// アプリ登録画面: アプリ単位の手動登録ではなく、APIキー1つに紐づくアカウント
/// 配下のアプリをまとめて取得して一括登録する仕様(仕様変更)。
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
        child: wrapWithLocalizedRouter(router),
      ),
    );
    // initialLocation は /dashboard のため、遷移前にデモアプリ自動登録
    // (appBootstrapProvider)の非同期処理が裏で走り出す。pumpAndSettle で
    // その完了まで待ってから /app-registration へ遷移する。
    router.go('/app-registration');
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitButton = find.text('アプリをまとめて取得して登録');
    // 画面は SingleChildScrollView 内にあり、デフォルトのテスト画面サイズでは
    // ボタンが画面外にはみ出すため、タップ前にスクロールして可視化する。
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
  }

  testWidgets('APIキー未入力のまま送信すると「APIキーを入力してください」が表示され、登録されない',
      (tester) async {
    await pumpRegistrationScreen(tester);
    final countBefore = container.read(connectedAppsProvider).length;

    await tapSubmit(tester);
    await tester.pump(); // SnackBarのアニメーション開始分だけpump(pumpAndSettleだと消えてしまう)

    expect(find.text('APIキーを入力してください'), findsOneWidget);
    // デモアプリ自動登録(initialLocation経由)以外に新規登録が発生していないこと。
    expect(container.read(connectedAppsProvider), hasLength(countBefore));
  });

  testWidgets(
      'APIキーを入力して送信すると、そのアカウント配下の全アプリがまとめて登録され、初回スキャン経由でダッシュボードに遷移する',
      (tester) async {
    await pumpRegistrationScreen(tester);

    final apiKeyField = find.byType(TextField);
    expect(apiKeyField, findsOneWidget); // APIキーの1つだけ
    await tester.enterText(apiKeyField, 'test-account-api-key');
    await tester.pump();

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    // 初回スキャン画面を経由し、成功すれば自動的にダッシュボードへ戻る
    // (initialScanProviderがAsyncDataになった時点でcontext.go('/dashboard'))。
    // MockDataService.discoverableAppsFor(iOS): Sample App 1 / Sample App 2 の2件。
    expect(find.text('Sample App 1'), findsWidgets);
    expect(find.text('Sample App 2'), findsWidgets);

    final registered = container
        .read(connectedAppsProvider)
        .where((a) => a.displayName.startsWith('Sample App'));
    expect(registered, hasLength(2));
    expect(
      registered.map((a) => a.bundleIdOrPackageName),
      containsAll(['works.petit.sampleapp1', 'works.petit.sampleapp2']),
    );
    expect(registered.every((a) => a.hasApiKeyRegistered), isTrue);
  });
}
