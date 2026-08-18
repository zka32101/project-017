import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../models/export_job.dart';
import '../services/export_service.dart';
import 'app_detail_providers.dart';

final exportServiceProvider = Provider<ExportService>((ref) => const ExportService());

/// エクスポート実行状態（1回の操作＝1リクエスト、Notifierで進行状況を保持）。
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

  /// 登録アプリ全件をまとめて1つのファイルへ出力する（全アプリ集約エクスポート）。
  /// アプリごとにreviewHistory/rejections/buildFailuresを個別に取得してから
  /// AppExportBundleへまとめ、ExportService.generateAll()へ渡す。
  Future<void> runExportAll({
    required List<ConnectedApp> apps,
    required ExportFormat format,
  }) async {
    state = const AsyncLoading();
    try {
      final bundles = <AppExportBundle>[];
      for (final app in apps) {
        final history = await ref.read(reviewHistoryProvider(app).future);
        final rejections = await ref.read(rejectionDetailsProvider(app).future);
        final buildFailures =
            await ref.read(buildFailureLogsProvider(app).future);
        bundles.add(AppExportBundle(
          app: app,
          reviewHistory: history,
          rejections: rejections,
          buildFailures: buildFailures,
        ));
      }
      final now = DateTime.now();

      final job = await ref.read(exportServiceProvider).generateAll(
            // 全アプリ集約時のuserIdは(空でも)先頭アプリのものを代表値として使う。
            // 呼び出し元(ExportScreen)はapps.isNotEmptyを保証してから呼ぶこと。
            userId: apps.first.userId,
            bundles: bundles,
            format: format,
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
