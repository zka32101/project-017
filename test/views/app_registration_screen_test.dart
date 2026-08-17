import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

/// iOSは実際のApp Store Connect APIを呼び出す実装になったため（discoverApps）、
/// ウィジェットテストでは実ネットワーク呼び出しを避けるためフェイクへ差し替える。
/// Androidはネットワーク呼び出しを行わず、入力されたpackageNameからその場で
/// DiscoverableAppを組み立てるだけ（PlayConsoleServiceの実装どおり）なので、
/// 実サービスをそのまま使ってテストできる。
class _FakeAppStoreConnectService implements ReviewStatusService {
  List<DiscoverableApp> response = const [];
  String? lastApiKey;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async {
    lastApiKey = apiKey;
    return ServiceSuccess(response);
  }
}

void main() {
  late ProviderContainer container;
  late _FakeAppStoreConnectService fakeIosService;

  setUp(() {
    fakeIosService = _FakeAppStoreConnectService()
      ..response = const [
        DiscoverableApp(
          bundleIdOrPackageName: 'works.petit.realapp1',
          displayName: 'Real App 1',
        ),
        DiscoverableApp(
          bundleIdOrPackageName: 'works.petit.realapp2',
          displayName: 'Real App 2',
        ),
      ];
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(fakeIosService),
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
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
  }

  group('iOS（App Store Connect API 実接続）', () {
    testWidgets('Issuer ID/Key ID/秘密鍵が未入力のまま送信すると専用メッセージが表示され、登録されない',
        (tester) async {
      await pumpRegistrationScreen(tester);
      final countBefore = container.read(connectedAppsProvider).length;

      await tapSubmit(tester);
      await tester.pump();

      expect(find.text('Issuer ID・Key ID・秘密鍵をすべて入力してください'), findsOneWidget);
      expect(container.read(connectedAppsProvider), hasLength(countBefore));
    });

    testWidgets('3項目を入力して送信すると、discoverAppsがJSON化された認証情報で呼ばれ、'
        '返ってきた全アプリが登録される', (tester) async {
      await pumpRegistrationScreen(tester);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3)); // Issuer ID / Key ID / 秘密鍵
      await tester.enterText(fields.at(0), 'issuer-123');
      await tester.enterText(fields.at(1), 'key-456');
      await tester.enterText(
          fields.at(2), '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----');
      await tester.pump();

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Real App 1'), findsWidgets);
      expect(find.text('Real App 2'), findsWidgets);

      final decoded = jsonDecode(fakeIosService.lastApiKey!) as Map<String, dynamic>;
      expect(decoded['issuerId'], 'issuer-123');
      expect(decoded['keyId'], 'key-456');
      expect(decoded['privateKey'], contains('BEGIN PRIVATE KEY'));

      final registered = container
          .read(connectedAppsProvider)
          .where((a) => a.displayName.startsWith('Real App'));
      expect(registered, hasLength(2));
      expect(registered.every((a) => a.hasApiKeyRegistered), isTrue);
    });
  });

  group('Android（パッケージ名を直接入力）', () {
    Future<void> switchToAndroid(WidgetTester tester) async {
      await tester.tap(find.text('Android'));
      await tester.pumpAndSettle();
    }

    testWidgets('APIキー・パッケージ名がどちらも未入力だと専用メッセージが表示される',
        (tester) async {
      await pumpRegistrationScreen(tester);
      await switchToAndroid(tester);

      await tapSubmit(tester);
      await tester.pump();

      expect(find.text('APIキーを入力してください'), findsOneWidget);
    });

    testWidgets('APIキーはあるがパッケージ名が空だと専用メッセージが表示される', (tester) async {
      await pumpRegistrationScreen(tester);
      await switchToAndroid(tester);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2)); // APIキー / パッケージ名
      await tester.enterText(fields.at(0), 'service-account-json');
      await tester.pump();

      await tapSubmit(tester);
      await tester.pump();

      expect(find.text('パッケージ名を1つ以上入力してください'), findsOneWidget);
    });

    testWidgets('パッケージ名を複数行入力すると、その場でアプリが組み立てられ一括登録される',
        (tester) async {
      await pumpRegistrationScreen(tester);
      await switchToAndroid(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'service-account-json');
      await tester.enterText(fields.at(1), 'works.petit.my_cool_app\nworks.petit.another');
      await tester.pump();

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      // PlayConsoleServiceはネットワークを叩かず、packageNameから機械的に
      // 表示名を生成する('my_cool_app' -> 'My Cool App')。
      expect(find.text('My Cool App'), findsWidgets);
      expect(find.text('Another'), findsWidgets);

      final registered = container
          .read(connectedAppsProvider)
          .where((a) => a.platform == PlatformType.android)
          .where((a) => a.bundleIdOrPackageName.startsWith('works.petit.'));
      expect(
        registered.map((a) => a.bundleIdOrPackageName),
        containsAll(['works.petit.my_cool_app', 'works.petit.another']),
      );
    });
  });
}
