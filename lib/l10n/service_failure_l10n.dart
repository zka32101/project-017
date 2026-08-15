import '../services/service_result.dart';
import 'gen/app_localizations.dart';

/// ServiceFailureException（Service層の失敗）を画面表示用のローカライズ済み
/// メッセージへ変換する。Service/Notifier層はBuildContextを持たないため、
/// 生の日本語メッセージではなく ServiceFailureReason（列挙値）だけを保持しており、
/// 実際の文言への変換はUI側（このヘルパー経由）で行う。
/// ServiceFailureException以外の予期しない例外は errorGeneric にフォールバックする。
String localizedErrorMessage(AppLocalizations l10n, Object error) {
  if (error is ServiceFailureException) {
    return switch (error.reason) {
      ServiceFailureReason.reviewStatus => l10n.errorReviewStatusFetchFailed,
      ServiceFailureReason.rejectionDetails =>
        l10n.errorRejectionDetailsFetchFailed,
      ServiceFailureReason.buildFailureLogs =>
        l10n.errorBuildFailureLogsFetchFailed,
      ServiceFailureReason.revenueSummary => l10n.errorRevenueFetchFailed,
      ServiceFailureReason.appDiscovery => l10n.errorAppDiscoveryFailed,
    };
  }
  return l10n.errorGeneric;
}
