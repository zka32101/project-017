import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/crash_summary.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/android_publisher_api_client.dart';
import 'package:ririkan/services/play_console_service.dart';
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

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) async =>
      const ServiceSuccess([]);
}

/// テスト用のダミーRSA秘密鍵(PKCS#8 PEM)。実在のGoogleサービスアカウントでは
/// なく、`openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt` で生成した
/// 使い捨てのテスト専用鍵(このテストの外では一切使用しない)。
/// AndroidPublisherApiClient.fetchLatestReviewStatus はJWT(RS256)署名の
/// 前段でこの鍵をパースするため、形式として妥当な鍵が必要。
const _testServiceAccountPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCt6zniJtIAzVM0
4on9vbnJcRw7auUP1SiDCl3Jhd07fmfppS95A89zTlgImKsSqrDKRKsLpYAPnWvp
mrVcgndT+rKi0B9Nb7F1Fst5aXzqe8JmSkVsmqEH67MXEwfvJEH6pMWpPRLKKIWU
odF9yLOEfjiG+nw4ff5boAHbuUOROpCqVFhBgBASFmV9cARV/zODbkFl+eVmJcPc
UflIbW4zIwvvtqplaXZgXLFDskby2+RrIZr1Ge6MC6WOs5Zepv0BrPIAtyP27s48
wK5mVc5acdQy584Nhv9LpNDNwGr06lxB8I9yrEF/JzALbeOeOTOV49/8JDbMG0wl
muUBp+1VAgMBAAECggEAFjxb0zE5akbWG43XLKzkIwAmJuac0LBlFJPvt8M4rNGV
gYbQEf3NuSVMFhVG0gUmw0WSRNPtEpIC6QQRqfk4PnFwA2buiZz9KEY4z5YQFX6r
NR7Lz33ZlsSoygtx2T5efSgx6VhYnaYepgkmWpmdchQdMAy4cxSQv7AubKQ8IkYP
nr+IvL6Aw/XeuPUozM1KX6/Vp5R9wo7wJ6BmACsjrnyNMn6NQk8uxm39JIxjrodI
HIgMA6/tHLFpgo8DQAOL8qu9pv8ZE87hbKQV6gfJte5obCExVwvAgQSwh7b70p9S
BKHz4k2jWeA/1cgNSkfXVUTfVBTIAHyjY+DCF0usZQKBgQDX2GsGlfCPPC+N61/s
Nommr0FWintamV9K/kOjvV49Edp/1k07EtxrMYPAF67H9U+QQ3fFJiJsgKaZvtVT
9Qu2pD/BrCiqqlcrDP55lJ2mFDE3vfAPmLzVoSvRDIqQfxusBAOVzIdZEXvUB8pB
F+ZLKgauunG0MbqDcbaRGTJnDwKBgQDORhFMKYV/O4+vbgOygZddzyC/Pwe2fRKm
AcFKvaZuhYTtxkFjUc3fqE0V4TRnWGHPgFpKSHIXTjJ5teHue9pGgtUWlR8rJglJ
MXwKaKCrmROoU0+B1SZStHzsbuLTWn0vZzP+f8ESmxUr/BDMCRW5D73jaPwMNCEt
Y2Gf86YFWwKBgQCRsa6Ecn8/X+PFiwRjgGinz5Jt5OngvLga+cgUZUWQOVXghnn5
DwEjhfelmRbMOCStfy0AMX54+Nn721lJ45U1gmbaxudoU7SlBY9b59oF+YlDU/0P
ugx0subNpAaABJxcHxWAbt9JWsjX1S5Lg+NaBxMdrBIGDK8V/JK8HGLuNwKBgDeF
VJKTeoNMnNgzXHtntj5hygawCHtuHt7gCg78DRgiiC0X9/GryyYwPs9s1pYai/k2
KxdjeJIdUijAdBek7pOcE48IhGMw0b8JusFyeAy4HzpncjcYEECipB1fm14YNSnV
NYGDEYzYgVJdfofsyhQN0KatU2pVfbihz10mT8GRAoGAWPcB3tphnTylnZNMozH7
+pqqXqBu8kELl21bSesQ2xiwmCqxTHv9ugvYZ1wAYpgWcG6BQ2yZdGwbMzYjq8/7
5fzBHNQmYlp3I7VIOWNL+M6XLPWq29J1QdwM1bc+oDauCWB139z6OwG86pvBtd8A
aiqFVreSFyGMRV4nYJ2ZB/0=
-----END PRIVATE KEY-----
''';

String _fakeServiceAccountJson() => jsonEncode({
      'type': 'service_account',
      'client_email': 'fake-service-account@example-project.iam.gserviceaccount.com',
      'private_key': _testServiceAccountPrivateKeyPem,
    });

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
        // discoverApps()自体はPlayConsoleServiceの実装(パッケージ名から
        // その場で組み立てる、HTTP通信なし)をそのまま使いたいので
        // PlayConsoleService自体はフェイクに差し替えない。ただし
        // fetchReviewStatus()は実API接続になっているため、登録直後に
        // /initial-scanへ遷移した際の一括プリフェッチ(initialScanProvider)が
        // 実ネットワーク呼び出しで失敗し、無限アニメーションのまま
        // pumpAndSettleがタイムアウトしないよう、AndroidPublisherApiClient
        // 側のHTTPクライアントだけをフェイクにする
        // (常にトラック無し=審査状態不明を返す、無害な応答)。
        playConsoleServiceProvider.overrideWith(
          (ref) => PlayConsoleService(
            secureStorageService: ref.watch(secureStorageServiceProvider),
            apiClient: AndroidPublisherApiClient(
              httpClient: MockClient((request) async {
                if (request.url.toString().contains('oauth2.googleapis.com')) {
                  return http.Response(
                    jsonEncode({'access_token': 'fake-token', 'expires_in': 3600}),
                    200,
                  );
                }
                if (request.url.path.endsWith('/tracks')) {
                  return http.Response(jsonEncode({'tracks': []}), 200);
                }
                // .../edits の作成(POST)応答。
                return http.Response(jsonEncode({'id': 'fake-edit-id'}), 200);
              }),
            ),
          ),
        ),
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
      // fetchReviewStatus(初回スキャンでの一括プリフェッチ)がJWT署名の前段で
      // 実際にJSONとしてパースするため、形式として妥当なサービスアカウント
      // JSONを渡す(discoverApps自体はこの中身を見ずpackageNameだけ見る)。
      await tester.enterText(fields.at(0), _fakeServiceAccountJson());
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
