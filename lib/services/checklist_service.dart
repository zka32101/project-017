import '../l10n/gen/app_localizations.dart';
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

  /// このServiceはBuildContextを持たないため、AppLocalizationsを呼び出し元
  /// （Widget側）から渡してもらう。
  String labelFor(AppLocalizations l10n, ChecklistItemKey key) => switch (key) {
        ChecklistItemKey.privacyPolicyUrl => l10n.checklistItemPrivacyPolicyUrl,
        ChecklistItemKey.ageRating => l10n.checklistItemAgeRating,
        ChecklistItemKey.screenshotSize => l10n.checklistItemScreenshotSize,
        ChecklistItemKey.metadataRequiredFields =>
          l10n.checklistItemMetadataRequiredFields,
        ChecklistItemKey.contactInfo => l10n.checklistItemContactInfo,
        ChecklistItemKey.demoAccount => l10n.checklistItemDemoAccount,
        ChecklistItemKey.exportComplianceInfo =>
          l10n.checklistItemExportComplianceInfo,
      };
}
