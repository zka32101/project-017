/// 提出前チェックリストの固定マスタキー（Apple/Googleガイドライン頻出リジェクト理由から作成、
/// 四半期メンテナンス想定）
enum ChecklistItemKey {
  privacyPolicyUrl,
  ageRating,
  screenshotSize,
  metadataRequiredFields,
  contactInfo,
  demoAccount,
  exportComplianceInfo,
}

enum ChecklistResult { pass, fail, warning, unchecked }

/// SubmissionChecklistItem { id, connectedAppId, itemKey, checkedAt, result }
class SubmissionChecklistItem {
  final String id;
  final String connectedAppId;
  final ChecklistItemKey itemKey;
  final DateTime? checkedAt;
  final ChecklistResult result;

  const SubmissionChecklistItem({
    required this.id,
    required this.connectedAppId,
    required this.itemKey,
    this.checkedAt,
    this.result = ChecklistResult.unchecked,
  });

  SubmissionChecklistItem copyWithResult(
    ChecklistResult newResult,
    DateTime checkedAt,
  ) =>
      SubmissionChecklistItem(
        id: id,
        connectedAppId: connectedAppId,
        itemKey: itemKey,
        checkedAt: checkedAt,
        result: newResult,
      );

  factory SubmissionChecklistItem.fromJson(Map<String, dynamic> json) =>
      SubmissionChecklistItem(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        itemKey:
            ChecklistItemKey.values.firstWhere((e) => e.name == json['itemKey']),
        checkedAt: json['checkedAt'] == null
            ? null
            : DateTime.parse(json['checkedAt'] as String),
        result: ChecklistResult.values.firstWhere(
          (e) => e.name == json['result'],
          orElse: () => ChecklistResult.unchecked,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'itemKey': itemKey.name,
        'checkedAt': checkedAt?.toIso8601String(),
        'result': result.name,
      };
}
