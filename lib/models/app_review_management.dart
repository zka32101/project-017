import 'review_status_type.dart';

/// アプリごとの審査状態の手動管理情報（管理項目の追加、Should機能）。
///
/// - manualStatusOverride: 審査状態を手動で一時的に上書きしたい場合の値。
///   nullなら自動取得値(latestReviewStatusProvider等)をそのまま表示する。
///   対象アプリの審査状態APIの取得が次に実際に成功すると自動的にクリアされ
///   (dashboard_providers.dartのlatestReviewStatusProvider参照)、以降は
///   再び自動取得値が優先される。表示のズレに気づいた時の一時的な訂正用途
///   であり、恒久的に自動更新を止める機能ではない。
/// - submittedAt / reviewStartedAt: 審査提出日・審査開始日（自己管理用の記録。
///   App Store Connect/Play Console のAPIには相当するフィールドが無いため、
///   完全にこのアプリ内だけのローカル管理情報）。
/// - note: 対応履歴・メモの自由記述欄。
class AppReviewManagement {
  final String connectedAppId;
  final ReviewStatusType? manualStatusOverride;
  final DateTime? submittedAt;
  final DateTime? reviewStartedAt;
  final String note;
  final DateTime? updatedAt;

  const AppReviewManagement({
    required this.connectedAppId,
    this.manualStatusOverride,
    this.submittedAt,
    this.reviewStartedAt,
    this.note = '',
    this.updatedAt,
  });

  factory AppReviewManagement.empty(String connectedAppId) =>
      AppReviewManagement(connectedAppId: connectedAppId);

  /// 何も設定されていない(初期状態のまま)かどうか。
  bool get isEmpty =>
      manualStatusOverride == null &&
      submittedAt == null &&
      reviewStartedAt == null &&
      note.isEmpty;

  factory AppReviewManagement.fromJson(Map<String, dynamic> json) =>
      AppReviewManagement(
        connectedAppId: json['connectedAppId'] as String,
        manualStatusOverride: json['manualStatusOverride'] == null
            ? null
            : ReviewStatusType.fromKey(json['manualStatusOverride'] as String),
        submittedAt: json['submittedAt'] == null
            ? null
            : DateTime.tryParse(json['submittedAt'] as String),
        reviewStartedAt: json['reviewStartedAt'] == null
            ? null
            : DateTime.tryParse(json['reviewStartedAt'] as String),
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'connectedAppId': connectedAppId,
        'manualStatusOverride': manualStatusOverride?.name,
        'submittedAt': submittedAt?.toIso8601String(),
        'reviewStartedAt': reviewStartedAt?.toIso8601String(),
        'note': note,
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
