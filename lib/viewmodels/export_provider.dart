import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../models/export_job.dart';
import '../services/export_service.dart';
import 'app_detail_providers.dart';

final exportServiceProvider = Provider<ExportService>((ref) => const ExportService());

/// エクスポート実行状態（1回の操作＝1リクエスト、Notifierで進行状況を保持）。
/// MVPは単一アプリのエクスポートのみ対応（ExportJob.connectedAppId=null の全アプリ集約は次フェーズ）。
class ExportNotifier extends Notifier<AsyncValue<ExportJob>?> {
  @override
  AsyncValue<ExportJob>? build() => null;

  Future<void> runExport({
    required ConnectedApp app,
    required ExportFormat format,
  }) async {
    state = const AsyncLoading();
    try {
      final history = await ref.read(reviewHistoryProvider(app).future);
      final rejections = await ref.read(rejectionDetailsProvider(app).future);
      final buildFailures = await ref.read(buildFailureLogsProvider(app).future);
      final now = DateTime.now();

      final job = await ref.read(exportServiceProvider).generate(
            userId: app.userId,
            app: app,
            format: format,
            reviewHistory: history,
            rejections: rejections,
            buildFailures: buildFailures,
            dateRange: DateTimeRange(
              start: now.subtract(const Duration(days: 90)),
              end: now,
            ),
          );
      state = AsyncData(job);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = null;
}

final exportProvider =
    NotifierProvider<ExportNotifier, AsyncValue<ExportJob>?>(ExportNotifier.new);
