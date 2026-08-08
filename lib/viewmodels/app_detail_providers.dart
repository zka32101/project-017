import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/crash_summary.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import '../models/revenue_summary.dart';
import '../services/mock_data_service.dart';
import '../services/service_result.dart';
import 'service_providers.dart';

/// アプリ詳細画面: クラッシュ推移タブ（Firebase Crashlytics連携、Must#3）。
/// MVP段階はモックデータ、実接続はCrashlyticsService実装時に置き換える。
final crashSummariesProvider =
    FutureProvider.family<List<CrashSummary>, ConnectedApp>((ref, app) async {
  const mock = MockDataService();
  return mock.crashSummariesFor(app.id);
});

/// アプリ詳細画面: 売上・DL数サマリータブ（Should機能、RevenueCat連携）
final revenueSummaryProvider =
    FutureProvider.family<List<RevenueSummary>, ConnectedApp>((ref, app) async {
  final service = ref.watch(revenueCatServiceProvider);
  final result = await service.fetchRevenueSummary(app);
  switch (result) {
    case ServiceSuccess<List<RevenueSummary>>(:final data):
      return data;
    case ServiceFailure<List<RevenueSummary>>():
      return const [];
  }
});

/// アプリ詳細画面: 審査履歴タブ
final reviewHistoryProvider =
    FutureProvider.family<List<ReviewStatusSnapshot>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  final result = await service.fetchReviewStatus(app);
  switch (result) {
    case ServiceSuccess<List<ReviewStatusSnapshot>>(:final data):
      return data;
    case ServiceFailure<List<ReviewStatusSnapshot>>():
      return const [];
  }
});

/// アプリ詳細画面: リジェクト理由タブ
final rejectionDetailsProvider =
    FutureProvider.family<List<RejectionDetail>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  final result = await service.fetchRejectionDetails(app);
  switch (result) {
    case ServiceSuccess<List<RejectionDetail>>(:final data):
      return data;
    case ServiceFailure<List<RejectionDetail>>():
      return const [];
  }
});

/// アプリ詳細画面: ビルド失敗ログタブ
final buildFailureLogsProvider =
    FutureProvider.family<List<BuildFailureLog>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  final result = await service.fetchBuildFailureLogs(app);
  switch (result) {
    case ServiceSuccess<List<BuildFailureLog>>(:final data):
      return data;
    case ServiceFailure<List<BuildFailureLog>>():
      return const [];
  }
});
