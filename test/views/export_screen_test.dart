import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/export_job.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/export_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/export_provider.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

/// generate()自体はdart:io/path_providerでファイルへ書き込むため、
/// flutter test環境では実行できない。UI（成功表示・共有ボタン活性化等）だけを
/// 検証したいので、ファイルI/Oを行わない固定成功レスポンスに差し替える。
class _FakeExportService extends ExportService {
  const _FakeExportService();

  @override
  Future<ExportJob> generate({
    required String userId,
    required ConnectedApp app,
    required ExportFormat format,
    required List<ReviewStatusSnapshot> reviewHistory,
    required List<RejectionDetail> rejections,
    required List<BuildFailureLog> buildFailures,
    required DateTimeRange dateRange,
  }) async {
    return ExportJob(
      id: 'fake-export-id',
      userId: userId,
      connectedAppId: app.id,
      format: format,
      dateRange: dateRange,
      status: ExportJobStatus.ready,
      fileUrl: '/fake/path/export.${format == ExportFormat.pdf ? 'pdf' : 'csv'}',
      expiresAt: DateTime(2026, 8, 20),
    );
  }

  @override
  Future<ExportJob> generateAll({
    required String userId,
    required List<AppExportBundle> bundles,
    required ExportFormat format,
    required DateTimeRange dateRange,
  }) async {
    return ExportJob(
      id: 'fake-export-all-id',
      userId: userId,
      format: format,
      dateRange: dateRange,
      status: ExportJobStatus.ready,
      fileUrl: '/fake/path/export_all.${format == ExportFormat.pdf ? 'pdf' : 'csv'}',
      expiresAt: DateTime(2026, 8, 20),
    );
  }
}

void main() {
  testWidgets('エクスポートを生成すると成功カードが表示される', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        exportServiceProvider.overrideWithValue(const _FakeExportService()),
        // AppStoreConnectService.fetchReviewStatusは実API接続になっているため、
        // エクスポート対象の審査履歴プリフェッチが実ネットワーク呼び出しで
        // 失敗しないよう明示的にフェイクへ差し替える。
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(FakeReviewStatusService()),
      ],
    );
    addTearDown(container.dispose);

    final app = await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'エクスポート対象アプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/export/${app.id}');
    await tester.pumpAndSettle();

    expect(find.text('エクスポートを生成'), findsOneWidget);

    await tester.tap(find.text('エクスポートを生成'));
    await tester.pumpAndSettle();

    expect(find.text('PDF を生成しました'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
  });

  testWidgets('全アプリ集約エクスポート(/export-all)でも成功カードが表示される', (tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        exportServiceProvider.overrideWithValue(const _FakeExportService()),
        reviewStatusServiceProvider(PlatformType.ios)
            .overrideWithValue(FakeReviewStatusService()),
        reviewStatusServiceProvider(PlatformType.android)
            .overrideWithValue(FakeReviewStatusService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: '集約対象アプリ1',
          apiKey: 'k',
        );
    await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.android,
          bundleIdOrPackageName: 'works.petit.app2',
          displayName: '集約対象アプリ2',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/export-all');
    await tester.pumpAndSettle();

    expect(find.text('全アプリ集約エクスポート'), findsOneWidget);
    expect(find.text('エクスポートを生成'), findsOneWidget);

    await tester.tap(find.text('エクスポートを生成'));
    await tester.pumpAndSettle();

    expect(find.text('PDF を生成しました'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
  });
}
