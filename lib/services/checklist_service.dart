import '../models/submission_checklist_item.dart';

/// 提出前チェックリストの項目マスタ管理（Should機能、設計書 Step6.5で四半期メンテナンス想定）。
class ChecklistService {
  const ChecklistService();

  /// Apple/Googleガイドライン頻出リジェクト理由から作成した初期セット。
  List<SubmissionChecklistItem> defaultChecklistFor(String connectedAppId) {
    return ChecklistItemKey.values
        .map((key) => SubmissionChecklistItem(
              id: '${connectedAppId}_${key.name}',
              connectedAppId: connectedAppId,
              itemKey: key,
            ))
        .toList();
  }

  String labelFor(ChecklistItemKey key) => switch (key) {
        ChecklistItemKey.privacyPolicyUrl => 'プライバシーポリシーURLの有効性',
        ChecklistItemKey.ageRating => '年齢設定',
        ChecklistItemKey.screenshotSize => 'スクリーンショット規定サイズ',
        ChecklistItemKey.metadataRequiredFields => 'メタデータ必須項目',
        ChecklistItemKey.contactInfo => '連絡先情報',
        ChecklistItemKey.demoAccount => '審査用デモアカウント',
        ChecklistItemKey.exportComplianceInfo => '暗号化・輸出コンプライアンス情報',
      };
}
