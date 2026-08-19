import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/crash_summary.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import '../models/revenue_summary.dart';
import '../services/service_result.dart';
import 'service_providers.dart';

/// アプリ詳細画面: クラッシュ推移タブ。
/// Android: Play Developer Reporting API による実データ。
/// iOS: Apple公式には公開エンドポイントが無いためMockDataServiceのまま
/// (詳細はAppStoreConnectServiceのドキュメントコメントを参照)。
final crashSummariesProvider =
    FutureProvider.family<List<CrashSummary>, ConnectedApp>((ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  return (await service.fetchCrashSummaries(app)).unwrap();
});

/// アプリ詳細画面: 売上・DL数サマリータブ（Should機能、RevenueCat連携）
final revenueSummaryProvider =
    FutureProvider.family<List<RevenueSummary>, ConnectedApp>((ref, app) async {
  final service = ref.watch(revenueCatServiceProvider);
  return (await service.fetchRevenueSummary(app)).unwrap();
});

/// アプリ詳細画面: 審査履歴タブ
final reviewHistoryProvider =
    FutureProvider.family<List<ReviewStatusSnapshot>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  return (await service.fetchReviewStatus(app)).unwrap();
});

/// アプリ詳細画面: リジェクト理由タブ
final rejectionDetailsProvider =
    FutureProvider.family<List<RejectionDetail>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  return (await service.fetchRejectionDetails(app)).unwrap();
});

/// アプリ詳細画面: ビルド失敗ログタブ
final buildFailureLogsProvider =
    FutureProvider.family<List<BuildFailureLog>, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  return (await service.fetchBuildFailureLogs(app)).unwrap();
});
