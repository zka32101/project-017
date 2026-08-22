import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/crash_summary.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/export_job.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/export_service.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/viewmodels/export_provider.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

/// 3種のデータをそれぞれ固定で返すテスト用Service。日付範囲(dateRange)の
/// フィルタリングを検証するため、90日より昔のデータを1件ずつ混ぜておく。
class _FixedDataReviewStatusService implements ReviewStatusService {
  _FixedDataReviewStatusService(this.now);

  final DateTime now;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async => ServiceSuccess([
    ReviewStatusSnapshot(
      id: '${app.id}_recent',
      connectedAppId: app.id,
      versionString: '1.0.0',
      statusType: ReviewStatusType.live,
      fetchedAt: now.subtract(const Duration(days: 10)), // 範囲内
    ),
    ReviewStatusSnapshot(
      id: '${app.id}_old',
      connectedAppId: app.id,
      versionString: '0.9.0',
      statusType: ReviewStatusType.live,
      fetchedAt: now.subtract(const Duration(days: 200)), // 範囲外
    ),
  ]);

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async => ServiceSuccess([
    RejectionDetail(
      id: '${app.id}_rej_recent',
      reviewStatusSnapshotId: 's1',
      connectedAppId: app.id,
      resolutionCenterMessage: '最近のリジェクト',
      rejectedAt: now.subtract(const Duration(days: 10)), // 範囲内
    ),
    RejectionDetail(
      id: '${app.id}_rej_old',
      reviewStatusSnapshotId: 's2',
      connectedAppId: app.id,
      resolutionCenterMessage: '古いリジェクト',
      rejectedAt: now.subtract(const Duration(days: 200)), // 範囲外
    ),
  ]);

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async => ServiceSuccess([
    BuildFailureLog(
      id: '${app.id}_build_recent',
      connectedAppId: app.id,
      buildNumber: '42',
      platform: app.platform,
      failureReason: '最近の失敗',
      occurredAt: now.subtract(const Duration(days: 10)), // 範囲内
    ),
    BuildFailureLog(
      id: '${app.id}_build_old',
      connectedAppId: app.id,
      buildNumber: '1',
      platform: app.platform,
      failureReason: '古い失敗',
      occurredAt: now.subtract(const Duration(days: 200)), // 範囲外
    ),
  ]);

  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async => const ServiceSuccess([]);

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) async => const ServiceSuccess([]);
}

/// generate()/generateAll()に実際に渡された引数を記録するだけのフェイク。
/// ファイルI/O(path_provider)には一切触れない。
class _CapturingExportService extends ExportService {
  const _CapturingExportService(this.captured);

  final List<Map<String, dynamic>> captured;

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
    captured.add({
      'reviewHistory': reviewHistory,
      'rejections': rejections,
      'buildFailures': buildFailures,
    });
    return ExportJob(
      id: 'job1',
      userId: userId,
      connectedAppId: app.id,
      format: format,
      dateRange: dateRange,
      status: ExportJobStatus.ready,
      fileUrl: '/tmp/fake.csv',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  @override
  Future<ExportJob> generateAll({
    required String userId,
    required List<AppExportBundle> bundles,
    required ExportFormat format,
    required DateTimeRange dateRange,
  }) async {
    captured.add({
      'reviewHistory': bundles.expand((b) => b.reviewHistory).toList(),
      'rejections': bundles.expand((b) => b.rejections).toList(),
      'buildFailures': bundles.expand((b) => b.buildFailures).toList(),
    });
    return ExportJob(
      id: 'job1',
      userId: userId,
      format: format,
      dateRange: dateRange,
      status: ExportJobStatus.ready,
      fileUrl: '/tmp/fake.csv',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

void main() {
  group('ExportNotifier（dateRangeの実フィルタリング）', () {
    test('runExport: 過去90日より前のデータはExportServiceへ渡す前に除外される', () async {
      final captured = <Map<String, dynamic>>[];
      final container = ProviderContainer(
        overrides: [
          reviewStatusServiceProvider(
            PlatformType.ios,
          ).overrideWithValue(_FixedDataReviewStatusService(DateTime.now())),
          exportServiceProvider.overrideWithValue(
            _CapturingExportService(captured),
          ),
        ],
      );
      addTearDown(container.dispose);

      const app = ConnectedApp(
        id: 'app1',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.app1',
        displayName: 'テストアプリ',
        sortOrder: 0,
      );

      await container
          .read(exportProvider.notifier)
          .runExport(app: app, format: ExportFormat.csv);

      expect(captured, hasLength(1));
      final reviewHistory =
          captured.single['reviewHistory'] as List<ReviewStatusSnapshot>;
      final rejections = captured.single['rejections'] as List<RejectionDetail>;
      final buildFailures =
          captured.single['buildFailures'] as List<BuildFailureLog>;

      expect(reviewHistory.map((s) => s.id), ['app1_recent']);
      expect(rejections.map((r) => r.id), ['app1_rej_recent']);
      expect(buildFailures.map((b) => b.id), ['app1_build_recent']);

      final state = container.read(exportProvider);
      expect(state?.value?.status, ExportJobStatus.ready);
    });

    test('runExportAll: 全アプリ集約でも同様に90日より前のデータは除外される', () async {
      final captured = <Map<String, dynamic>>[];
      final container = ProviderContainer(
        overrides: [
          reviewStatusServiceProvider(
            PlatformType.ios,
          ).overrideWithValue(_FixedDataReviewStatusService(DateTime.now())),
          exportServiceProvider.overrideWithValue(
            _CapturingExportService(captured),
          ),
        ],
      );
      addTearDown(container.dispose);

      const app = ConnectedApp(
        id: 'app1',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.app1',
        displayName: 'テストアプリ',
        sortOrder: 0,
      );

      await container
          .read(exportProvider.notifier)
          .runExportAll(apps: [app], format: ExportFormat.csv);

      expect(captured, hasLength(1));
      final reviewHistory =
          captured.single['reviewHistory'] as List<ReviewStatusSnapshot>;
      expect(reviewHistory.map((s) => s.id), ['app1_recent']);
    });
  });
}
