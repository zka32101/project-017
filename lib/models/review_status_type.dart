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

  String get label => switch (this) {
        ReviewStatusType.waitingReview => '審査待ち',
        ReviewStatusType.inReview => '審査中',
        ReviewStatusType.rejected => 'リジェクト',
        ReviewStatusType.approved => '承認済み',
        ReviewStatusType.live => '公開中',
      };
}
