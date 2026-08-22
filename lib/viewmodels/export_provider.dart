import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../models/export_job.dart';
import '../services/export_service.dart';
import 'app_detail_providers.dart';

final exportServiceProvider = Provider<ExportService>(
  (ref) => const ExportService(),
);

/// dateOf(item)がrange内(両端含む)のものだけ残す。ExportJob.dateRangeは
/// 以前はExportJobのメタデータとして持たせるだけで実際のフィルタには
/// 使われていなかった(常に過去90日分の全件がそのままレポートに載っていた)。
List<T> _withinRange<T>(
  List<T> items,
  DateTimeRange range,
  DateTime Function(T item) dateOf,
) => items
    .where(
      (item) =>
          !dateOf(item).isBefore(range.start) &&
          !dateOf(item).isAfter(range.end),
    )
    .toList();

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
      // 3つとも互いに依存しない独立した取得のため、直列にawaitせず並行実行する。
      final (history, rejections, buildFailures) = await (
        ref.read(reviewHistoryProvider(app).future),
        ref.read(rejectionDetailsProvider(app).future),
        ref.read(buildFailureLogsProvider(app).future),
      ).wait;
      final now = DateTime.now();
      final dateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 90)),
        end: now,
      );

      final job = await ref
          .read(exportServiceProvider)
          .generate(
            userId: app.userId,
            app: app,
            format: format,
            reviewHistory: _withinRange(history, dateRange, (s) => s.fetchedAt),
            rejections: _withinRange(
              rejections,
              dateRange,
              (r) => r.rejectedAt,
            ),
            buildFailures: _withinRange(
              buildFailures,
              dateRange,
              (b) => b.occurredAt,
            ),
            dateRange: dateRange,
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
      // アプリ間・各アプリ内の3種類の取得はいずれも互いに独立しているため、
      // 直列ループ(3×N回の逐次await)ではなく全アプリまとめて並行実行する。
      // Future.waitは入力順で結果を返すため、bundlesの並び順はapps同様に保たれる。
      final now = DateTime.now();
      final dateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 90)),
        end: now,
      );
      final bundles = await Future.wait(
        apps.map((app) async {
          final (history, rejections, buildFailures) = await (
            ref.read(reviewHistoryProvider(app).future),
            ref.read(rejectionDetailsProvider(app).future),
            ref.read(buildFailureLogsProvider(app).future),
          ).wait;
          return AppExportBundle(
            app: app,
            reviewHistory: _withinRange(history, dateRange, (s) => s.fetchedAt),
            rejections: _withinRange(
              rejections,
              dateRange,
              (r) => r.rejectedAt,
            ),
            buildFailures: _withinRange(
              buildFailures,
              dateRange,
              (b) => b.occurredAt,
            ),
          );
        }),
      );

      final job = await ref
          .read(exportServiceProvider)
          .generateAll(
            // 全アプリ集約時のuserIdは(空でも)先頭アプリのものを代表値として使う。
            // 呼び出し元(ExportScreen)はapps.isNotEmptyを保証してから呼ぶこと。
            userId: apps.first.userId,
            bundles: bundles,
            format: format,
            dateRange: dateRange,
          );
      state = AsyncData(job);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = null;
}

final exportProvider = NotifierProvider<ExportNotifier, AsyncValue<ExportJob>?>(
  ExportNotifier.new,
);
