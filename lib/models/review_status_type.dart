import '../l10n/gen/app_localizations.dart';

/// 審査状態（App Store Connect / Play Console 共通表現）
enum ReviewStatusType {
  waitingReview,
  inReview,
  rejected,
  approved,
  live;

  static ReviewStatusType fromKey(String key) {
    return ReviewStatusType.values.firstWhere(
      (e) => e.name == key,
      orElse: () => ReviewStatusType.waitingReview,
    );
  }

  /// モデル層はBuildContextを持たないため、AppLocalizationsを呼び出し元
  /// （Widget側）から渡してもらう。
  String label(AppLocalizations l10n) => switch (this) {
        ReviewStatusType.waitingReview => l10n.reviewStatusWaitingReview,
        ReviewStatusType.inReview => l10n.reviewStatusInReview,
        ReviewStatusType.rejected => l10n.reviewStatusRejected,
        ReviewStatusType.approved => l10n.reviewStatusApproved,
        ReviewStatusType.live => l10n.reviewStatusLive,
      };
}
