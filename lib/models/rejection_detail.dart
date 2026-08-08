/// RejectionDetail { id, reviewStatusSnapshotId, connectedAppId, guidelineNumber,
///   guidelineTitle, resolutionCenterMessage, rejectedAt, resolvedAt }
///
/// 構造化取得できない場合（設計書 Step4 参照）は resolutionCenterMessage に
/// ユーザーが手動コピペした本文を保存するフォールバックも許容する。
class RejectionDetail {
  final String id;
  final String reviewStatusSnapshotId;
  final String connectedAppId;
  final String? guidelineNumber;
  final String? guidelineTitle;
  final String resolutionCenterMessage;
  final DateTime rejectedAt;
  final DateTime? resolvedAt;

  const RejectionDetail({
    required this.id,
    required this.reviewStatusSnapshotId,
    required this.connectedAppId,
    this.guidelineNumber,
    this.guidelineTitle,
    required this.resolutionCenterMessage,
    required this.rejectedAt,
    this.resolvedAt,
  });

  bool get isResolved => resolvedAt != null;

  factory RejectionDetail.fromJson(Map<String, dynamic> json) =>
      RejectionDetail(
        id: json['id'] as String,
        reviewStatusSnapshotId: json['reviewStatusSnapshotId'] as String,
        connectedAppId: json['connectedAppId'] as String,
        guidelineNumber: json['guidelineNumber'] as String?,
        guidelineTitle: json['guidelineTitle'] as String?,
        resolutionCenterMessage: json['resolutionCenterMessage'] as String,
        rejectedAt: DateTime.parse(json['rejectedAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewStatusSnapshotId': reviewStatusSnapshotId,
        'connectedAppId': connectedAppId,
        'guidelineNumber': guidelineNumber,
        'guidelineTitle': guidelineTitle,
        'resolutionCenterMessage': resolutionCenterMessage,
        'rejectedAt': rejectedAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}
