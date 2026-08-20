import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_review_management.dart';
import '../models/review_status_type.dart';
import 'service_providers.dart';

/// アプリごとの審査状態管理情報(手動ステータス上書き・提出日/審査開始日・メモ)の
/// 状態管理。connectedAppId ごとに独立した状態を持つ
/// (FamilyNotifier、checklist_notifier.dartと同じパターン)。
class AppReviewManagementNotifier
    extends FamilyNotifier<AppReviewManagement, String> {
  @override
  AppReviewManagement build(String connectedAppId) =>
      AppReviewManagement.empty(connectedAppId);

  Future<void> setManualStatusOverride(ReviewStatusType? status) => _update(
        manualStatusOverride: status,
        submittedAt: state.submittedAt,
        reviewStartedAt: state.reviewStartedAt,
        note: state.note,
      );

  Future<void> setSubmittedAt(DateTime? date) => _update(
        manualStatusOverride: state.manualStatusOverride,
        submittedAt: date,
        reviewStartedAt: state.reviewStartedAt,
        note: state.note,
      );

  Future<void> setReviewStartedAt(DateTime? date) => _update(
        manualStatusOverride: state.manualStatusOverride,
        submittedAt: state.submittedAt,
        reviewStartedAt: date,
        note: state.note,
      );

  Future<void> setNote(String note) => _update(
        manualStatusOverride: state.manualStatusOverride,
        submittedAt: state.submittedAt,
        reviewStartedAt: state.reviewStartedAt,
        note: note,
      );

  /// 対象アプリの審査状態APIの取得が実際に成功した際、
  /// dashboard_providers.dartのlatestReviewStatusProviderから呼ばれる。
  /// 手動上書きは「次回の実取得成功まで」の一時的な訂正用途のため、ここで
  /// クリアする(AppReviewManagementのドキュメントコメント参照)。上書きが
  /// 設定されていない場合は何もしない(不要な永続化書き込みを避ける)。
  Future<void> clearManualStatusOverrideAfterFetch() async {
    if (state.manualStatusOverride == null) return;
    await setManualStatusOverride(null);
  }

  /// 永続化データからの復元用(appReviewManagementBootstrapProviderから呼ぶ)。
  void restore(AppReviewManagement saved) {
    state = saved;
  }

  Future<void> _update({
    required ReviewStatusType? manualStatusOverride,
    required DateTime? submittedAt,
    required DateTime? reviewStartedAt,
    required String note,
  }) async {
    state = AppReviewManagement(
      connectedAppId: state.connectedAppId,
      manualStatusOverride: manualStatusOverride,
      submittedAt: submittedAt,
      reviewStartedAt: reviewStartedAt,
      note: note,
      updatedAt: DateTime.now(),
    );
    await ref
        .read(localStoreServiceProvider)
        .saveManagement(state.connectedAppId, state);
  }
}

final appReviewManagementProvider = NotifierProvider.family<
    AppReviewManagementNotifier, AppReviewManagement, String>(
  AppReviewManagementNotifier.new,
);

/// connectedAppIdごとに一度だけ、永続化された管理情報を復元する
/// (checklistBootstrapProviderと同じ理由でbuild()内の暗黙的な副作用にせず、
/// 呼び出し側から明示的にwatchする設計にしている)。
final appReviewManagementBootstrapProvider =
    FutureProvider.family<void, String>((ref, connectedAppId) async {
  final saved =
      await ref.read(localStoreServiceProvider).loadManagement(connectedAppId);
  if (saved != null) {
    ref
        .read(appReviewManagementProvider(connectedAppId).notifier)
        .restore(saved);
  }
});
