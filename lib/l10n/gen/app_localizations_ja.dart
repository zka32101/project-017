// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'リリカン';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonAppNotFound => 'アプリが見つかりません';

  @override
  String get dashboardEmptyMessage => 'まだ登録アプリがありません';

  @override
  String get dashboardAddApp => 'アプリを追加';

  @override
  String get dashboardStatusUnknown => '状態未取得';

  @override
  String get dashboardStatusLoading => '取得中…';

  @override
  String get dashboardSearchHint => 'アプリを検索';

  @override
  String get dashboardFilterAll => 'すべて';

  @override
  String get dashboardSortLabel => '並び替え';

  @override
  String get dashboardSortManual => '手動(ドラッグ)';

  @override
  String get dashboardSortName => '名前順';

  @override
  String get dashboardSortPlatform => 'プラットフォーム別';

  @override
  String get dashboardNoMatchMessage => '条件に一致するアプリがありません';

  @override
  String get appRegistrationTitle => 'アプリ登録';

  @override
  String get appRegistrationApiKeyRequired => 'APIキーを入力してください';

  @override
  String get appRegistrationCredentialRequired =>
      'Issuer ID・Key ID・秘密鍵をすべて入力してください';

  @override
  String get appRegistrationPackageNamesRequired => 'パッケージ名を1つ以上入力してください';

  @override
  String get appRegistrationNoAppsFound => '紐づくアプリが見つかりませんでした';

  @override
  String appRegistrationFailed(String error) {
    return '登録に失敗しました: $error';
  }

  @override
  String get appRegistrationBulkFetchDescriptionIos =>
      'Issuer ID・Key ID・秘密鍵（.p8の内容）を入力すると、そのアカウントに紐づくアプリをApp Store Connect APIからまとめて取得して登録します（1件ずつの登録は不要です）。';

  @override
  String get appRegistrationBulkFetchDescriptionAndroid =>
      'Google Play Developer APIにはアプリを自動検出する仕組みが無いため、登録したいアプリのパッケージ名を入力してください（サービスアカウントJSONキーは共通で1つ入力すればOKです）。';

  @override
  String get appRegistrationIssuerIdLabel => 'Issuer ID';

  @override
  String get appRegistrationKeyIdLabel => 'Key ID';

  @override
  String get appRegistrationPrivateKeyLabel => '秘密鍵（.p8ファイルの中身）';

  @override
  String get appRegistrationPackageNamesLabel => 'パッケージ名（1行に1つ）';

  @override
  String get appRegistrationPackageNamesHint =>
      'works.petit.app1\nworks.petit.app2';

  @override
  String get appRegistrationIosStep1 => 'App Store Connect にログイン';

  @override
  String get appRegistrationIosStep2 => 'ユーザーとアクセス → 統合 → キーを生成';

  @override
  String get appRegistrationIosStep3 => '「App Manager」以上の最小権限スコープで発行';

  @override
  String get appRegistrationIosStep4 =>
      '発行された Issuer ID / Key ID / .p8 の内容をコピー';

  @override
  String get appRegistrationAndroidStep1 => 'Google Play Console にログイン';

  @override
  String get appRegistrationAndroidStep2 => 'API アクセス → サービスアカウントを作成';

  @override
  String get appRegistrationAndroidStep3 => '最小権限ロール（表示専用など）で発行';

  @override
  String get appRegistrationAndroidStep4 => 'サービスアカウントJSONキーの内容をコピー';

  @override
  String get appRegistrationApiKeyStepsTitle => 'APIキー発行手順（ユーザー作業）';

  @override
  String get appRegistrationApiKeyLabel => 'APIキー（端末内にのみ暗号化保存されます）';

  @override
  String get appRegistrationSubmit => 'アプリをまとめて取得して登録';

  @override
  String get appDetailExportTooltip => 'エクスポート';

  @override
  String get appDetailChecklistTooltip => '提出前チェックリスト';

  @override
  String get appDetailTabReviewHistory => '審査履歴';

  @override
  String get appDetailTabCrashTrend => 'クラッシュ推移';

  @override
  String get appDetailTabRevenue => '売上・DL数';

  @override
  String get appDetailTabRejection => 'リジェクト理由';

  @override
  String get appDetailTabBuildFailure => 'ビルド失敗ログ';

  @override
  String get appDetailReviewHistoryEmpty => '審査履歴はまだありません';

  @override
  String get appDetailCrashDataEmpty => 'クラッシュデータはまだありません';

  @override
  String appDetailCrashFreeRate(String rate, int count) {
    return 'クラッシュフリー率 $rate% ・ $count件';
  }

  @override
  String get appDetailRevenueEmpty => '売上データはまだありません';

  @override
  String appDetailRevenueSummaryLabel(int days) {
    return '直近$days日 売上';
  }

  @override
  String get appDetailDownloadsTotalLabel => 'DL数合計';

  @override
  String appDetailRevenueRow(String currency, String amount, int downloads) {
    return '$currency $amount ・ ${downloads}DL';
  }

  @override
  String get appDetailRejectionEmpty => 'リジェクト履歴はありません';

  @override
  String get appDetailRejectionUnknownReason => '理由不明';

  @override
  String get appDetailBuildFailureEmpty => 'ビルド失敗ログはありません';

  @override
  String appDetailBuildNumber(String number) {
    return 'Build $number';
  }

  @override
  String get errorReviewStatusFetchFailed => '審査状態の取得に失敗しました';

  @override
  String get errorRejectionDetailsFetchFailed => 'リジェクト理由の取得に失敗しました';

  @override
  String get errorBuildFailureLogsFetchFailed => 'ビルド失敗ログの取得に失敗しました';

  @override
  String get errorRevenueFetchFailed => '売上サマリーの取得に失敗しました';

  @override
  String get errorAppDiscoveryFailed => 'アプリ一覧の取得に失敗しました';

  @override
  String get errorCrashSummariesFetchFailed => 'クラッシュ情報の取得に失敗しました';

  @override
  String get errorGeneric => 'エラーが発生しました';

  @override
  String checklistTitle(String appName) {
    return '提出前チェックリスト・$appName';
  }

  @override
  String checklistProgress(int passCount, int total) {
    return '$passCount / $total 項目クリア';
  }

  @override
  String get checklistResultUnchecked => '未確認';

  @override
  String get checklistResultPass => '合格';

  @override
  String get checklistResultWarning => '要確認';

  @override
  String get checklistResultFail => '未対応';

  @override
  String get checklistItemPrivacyPolicyUrl => 'プライバシーポリシーURLの有効性';

  @override
  String get checklistItemAgeRating => '年齢設定';

  @override
  String get checklistItemScreenshotSize => 'スクリーンショット規定サイズ';

  @override
  String get checklistItemMetadataRequiredFields => 'メタデータ必須項目';

  @override
  String get checklistItemContactInfo => '連絡先情報';

  @override
  String get checklistItemDemoAccount => '審査用デモアカウント';

  @override
  String get checklistItemExportComplianceInfo => '暗号化・輸出コンプライアンス情報';

  @override
  String exportTitle(String appName) {
    return 'エクスポート・$appName';
  }

  @override
  String get exportDescription => '審査履歴・リジェクト理由・ビルド失敗ログを1つのファイルにまとめます。';

  @override
  String get exportGenerate => 'エクスポートを生成';

  @override
  String exportFailedWithReason(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get exportFailed => 'エクスポートに失敗しました';

  @override
  String exportGenerated(String format) {
    return '$format を生成しました';
  }

  @override
  String exportExpiresAt(String date) {
    return '有効期限: $dateまで';
  }

  @override
  String get exportShare => '共有';

  @override
  String get onboardingPage1Title => '複数アプリの状態を、1つの管制塔で';

  @override
  String get onboardingPage1Body =>
      'App Store Connect と Play Console をまたいで、審査状態・ビルド状態をまとめて見張ります。';

  @override
  String get onboardingPage2Title => '登録後は完全自動';

  @override
  String get onboardingPage2Body => '審査通過・リジェクト・ビルド完了を、あなたが確認しに行く前に通知します。';

  @override
  String get onboardingPage3Title => 'APIキーは端末内だけで保管';

  @override
  String get onboardingPage3Body =>
      'Keychain / EncryptedSharedPreferences に保存し、サーバーには実行時以外保存しません。';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => 'はじめる';

  @override
  String get notificationPromptTitle => '審査通過・リジェクトを見逃さないために';

  @override
  String get notificationPromptBody =>
      'プッシュ通知を許可すると、状態が変わった瞬間にお知らせします。\n（本番実装ではここでOS標準の許可ダイアログを表示します）';

  @override
  String get notificationPromptAllow => '通知を許可する';

  @override
  String get notificationPromptLater => 'あとで';

  @override
  String get paywallTitle => '3本目のアプリを管理するには';

  @override
  String get paywallBody =>
      'Pro プランでアプリ登録数が無制限になります。\nプッシュ通知即時化・ウィジェット・チーム共有も利用可能です。\n¥600/月 または ¥5,000/年';

  @override
  String get paywallUpgrade => 'Pro にアップグレード';

  @override
  String get paywallLater => 'あとで';

  @override
  String get initialScanMessage => '登録したアプリの状態を確認しています…';

  @override
  String get initialScanSubMessage => '管制塔が起動しています';

  @override
  String get initialScanProceedAnyway => 'ダッシュボードへ進む';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsPlanLabel => 'プラン';

  @override
  String get settingsPlanPro => 'Pro（無制限）';

  @override
  String get settingsPlanFree => 'Free（2アプリまで）';

  @override
  String get settingsAppsManagementLabel => '登録アプリ管理';

  @override
  String settingsAppsCount(int count) {
    return '$count件登録中';
  }

  @override
  String get settingsNotificationLabel => '通知設定';

  @override
  String get settingsNotificationSubtitle => '毎朝の状態サマリー通知（未実装・次フェーズ）';

  @override
  String settingsRemoveFailed(String error) {
    return '削除に失敗しました: $error';
  }

  @override
  String settingsApiKeyMasked(String masked) {
    return 'APIキー: $masked';
  }

  @override
  String get reviewStatusWaitingReview => '審査待ち';

  @override
  String get reviewStatusInReview => '審査中';

  @override
  String get reviewStatusRejected => 'リジェクト';

  @override
  String get reviewStatusApproved => '承認済み';

  @override
  String get reviewStatusLive => '公開中';
}
