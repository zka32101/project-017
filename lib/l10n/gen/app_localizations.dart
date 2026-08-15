import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// アプリ名・ダッシュボードのAppBarタイトル
  ///
  /// In ja, this message translates to:
  /// **'リリカン'**
  String get appTitle;

  /// No description provided for @commonRetry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get commonRetry;

  /// No description provided for @commonAppNotFound.
  ///
  /// In ja, this message translates to:
  /// **'アプリが見つかりません'**
  String get commonAppNotFound;

  /// No description provided for @dashboardEmptyMessage.
  ///
  /// In ja, this message translates to:
  /// **'まだ登録アプリがありません'**
  String get dashboardEmptyMessage;

  /// No description provided for @dashboardAddApp.
  ///
  /// In ja, this message translates to:
  /// **'アプリを追加'**
  String get dashboardAddApp;

  /// No description provided for @dashboardStatusUnknown.
  ///
  /// In ja, this message translates to:
  /// **'状態未取得'**
  String get dashboardStatusUnknown;

  /// No description provided for @dashboardStatusLoading.
  ///
  /// In ja, this message translates to:
  /// **'取得中…'**
  String get dashboardStatusLoading;

  /// No description provided for @appRegistrationTitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリ登録'**
  String get appRegistrationTitle;

  /// No description provided for @appRegistrationFillAllFields.
  ///
  /// In ja, this message translates to:
  /// **'すべての項目を入力してください'**
  String get appRegistrationFillAllFields;

  /// No description provided for @appRegistrationFailed.
  ///
  /// In ja, this message translates to:
  /// **'登録に失敗しました: {error}'**
  String appRegistrationFailed(String error);

  /// No description provided for @appRegistrationProgressAlmostDone.
  ///
  /// In ja, this message translates to:
  /// **'あと1ステップで自動監視が始まります'**
  String get appRegistrationProgressAlmostDone;

  /// No description provided for @appRegistrationProgressStart.
  ///
  /// In ja, this message translates to:
  /// **'ここだけ頑張れば、あとは全部自動です'**
  String get appRegistrationProgressStart;

  /// No description provided for @appRegistrationIosStep1.
  ///
  /// In ja, this message translates to:
  /// **'App Store Connect にログイン'**
  String get appRegistrationIosStep1;

  /// No description provided for @appRegistrationIosStep2.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーとアクセス → 統合 → キーを生成'**
  String get appRegistrationIosStep2;

  /// No description provided for @appRegistrationIosStep3.
  ///
  /// In ja, this message translates to:
  /// **'「App Manager」以上の最小権限スコープで発行'**
  String get appRegistrationIosStep3;

  /// No description provided for @appRegistrationIosStep4.
  ///
  /// In ja, this message translates to:
  /// **'発行された Issuer ID / Key ID / .p8 の内容をコピー'**
  String get appRegistrationIosStep4;

  /// No description provided for @appRegistrationAndroidStep1.
  ///
  /// In ja, this message translates to:
  /// **'Google Play Console にログイン'**
  String get appRegistrationAndroidStep1;

  /// No description provided for @appRegistrationAndroidStep2.
  ///
  /// In ja, this message translates to:
  /// **'API アクセス → サービスアカウントを作成'**
  String get appRegistrationAndroidStep2;

  /// No description provided for @appRegistrationAndroidStep3.
  ///
  /// In ja, this message translates to:
  /// **'最小権限ロール（表示専用など）で発行'**
  String get appRegistrationAndroidStep3;

  /// No description provided for @appRegistrationAndroidStep4.
  ///
  /// In ja, this message translates to:
  /// **'サービスアカウントJSONキーの内容をコピー'**
  String get appRegistrationAndroidStep4;

  /// No description provided for @appRegistrationApiKeyStepsTitle.
  ///
  /// In ja, this message translates to:
  /// **'APIキー発行手順（ユーザー作業）'**
  String get appRegistrationApiKeyStepsTitle;

  /// No description provided for @appRegistrationDisplayNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'アプリの表示名'**
  String get appRegistrationDisplayNameLabel;

  /// No description provided for @appRegistrationBundleIdLabel.
  ///
  /// In ja, this message translates to:
  /// **'Bundle ID'**
  String get appRegistrationBundleIdLabel;

  /// No description provided for @appRegistrationPackageNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'Package Name'**
  String get appRegistrationPackageNameLabel;

  /// No description provided for @appRegistrationApiKeyLabel.
  ///
  /// In ja, this message translates to:
  /// **'APIキー（端末内にのみ暗号化保存されます）'**
  String get appRegistrationApiKeyLabel;

  /// No description provided for @appRegistrationSubmit.
  ///
  /// In ja, this message translates to:
  /// **'登録して初回スキャンを開始'**
  String get appRegistrationSubmit;

  /// No description provided for @appDetailExportTooltip.
  ///
  /// In ja, this message translates to:
  /// **'エクスポート'**
  String get appDetailExportTooltip;

  /// No description provided for @appDetailChecklistTooltip.
  ///
  /// In ja, this message translates to:
  /// **'提出前チェックリスト'**
  String get appDetailChecklistTooltip;

  /// No description provided for @appDetailTabReviewHistory.
  ///
  /// In ja, this message translates to:
  /// **'審査履歴'**
  String get appDetailTabReviewHistory;

  /// No description provided for @appDetailTabCrashTrend.
  ///
  /// In ja, this message translates to:
  /// **'クラッシュ推移'**
  String get appDetailTabCrashTrend;

  /// No description provided for @appDetailTabRevenue.
  ///
  /// In ja, this message translates to:
  /// **'売上・DL数'**
  String get appDetailTabRevenue;

  /// No description provided for @appDetailTabRejection.
  ///
  /// In ja, this message translates to:
  /// **'リジェクト理由'**
  String get appDetailTabRejection;

  /// No description provided for @appDetailTabBuildFailure.
  ///
  /// In ja, this message translates to:
  /// **'ビルド失敗ログ'**
  String get appDetailTabBuildFailure;

  /// No description provided for @appDetailReviewHistoryEmpty.
  ///
  /// In ja, this message translates to:
  /// **'審査履歴はまだありません'**
  String get appDetailReviewHistoryEmpty;

  /// No description provided for @appDetailCrashDataEmpty.
  ///
  /// In ja, this message translates to:
  /// **'クラッシュデータはまだありません'**
  String get appDetailCrashDataEmpty;

  /// No description provided for @appDetailCrashFreeRate.
  ///
  /// In ja, this message translates to:
  /// **'クラッシュフリー率 {rate}% ・ {count}件'**
  String appDetailCrashFreeRate(String rate, int count);

  /// No description provided for @appDetailRevenueEmpty.
  ///
  /// In ja, this message translates to:
  /// **'売上データはまだありません'**
  String get appDetailRevenueEmpty;

  /// No description provided for @appDetailRevenueSummaryLabel.
  ///
  /// In ja, this message translates to:
  /// **'直近{days}日 売上'**
  String appDetailRevenueSummaryLabel(int days);

  /// No description provided for @appDetailDownloadsTotalLabel.
  ///
  /// In ja, this message translates to:
  /// **'DL数合計'**
  String get appDetailDownloadsTotalLabel;

  /// No description provided for @appDetailRevenueRow.
  ///
  /// In ja, this message translates to:
  /// **'{currency} {amount} ・ {downloads}DL'**
  String appDetailRevenueRow(String currency, String amount, int downloads);

  /// No description provided for @appDetailRejectionEmpty.
  ///
  /// In ja, this message translates to:
  /// **'リジェクト履歴はありません'**
  String get appDetailRejectionEmpty;

  /// No description provided for @appDetailRejectionUnknownReason.
  ///
  /// In ja, this message translates to:
  /// **'理由不明'**
  String get appDetailRejectionUnknownReason;

  /// No description provided for @appDetailBuildFailureEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ビルド失敗ログはありません'**
  String get appDetailBuildFailureEmpty;

  /// No description provided for @appDetailBuildNumber.
  ///
  /// In ja, this message translates to:
  /// **'Build {number}'**
  String appDetailBuildNumber(String number);

  /// No description provided for @errorReviewStatusFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'審査状態の取得に失敗しました'**
  String get errorReviewStatusFetchFailed;

  /// No description provided for @errorRejectionDetailsFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'リジェクト理由の取得に失敗しました'**
  String get errorRejectionDetailsFetchFailed;

  /// No description provided for @errorBuildFailureLogsFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'ビルド失敗ログの取得に失敗しました'**
  String get errorBuildFailureLogsFetchFailed;

  /// No description provided for @errorRevenueFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'売上サマリーの取得に失敗しました'**
  String get errorRevenueFetchFailed;

  /// No description provided for @errorGeneric.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました'**
  String get errorGeneric;

  /// No description provided for @checklistTitle.
  ///
  /// In ja, this message translates to:
  /// **'提出前チェックリスト・{appName}'**
  String checklistTitle(String appName);

  /// No description provided for @checklistProgress.
  ///
  /// In ja, this message translates to:
  /// **'{passCount} / {total} 項目クリア'**
  String checklistProgress(int passCount, int total);

  /// No description provided for @checklistResultUnchecked.
  ///
  /// In ja, this message translates to:
  /// **'未確認'**
  String get checklistResultUnchecked;

  /// No description provided for @checklistResultPass.
  ///
  /// In ja, this message translates to:
  /// **'合格'**
  String get checklistResultPass;

  /// No description provided for @checklistResultWarning.
  ///
  /// In ja, this message translates to:
  /// **'要確認'**
  String get checklistResultWarning;

  /// No description provided for @checklistResultFail.
  ///
  /// In ja, this message translates to:
  /// **'未対応'**
  String get checklistResultFail;

  /// No description provided for @checklistItemPrivacyPolicyUrl.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシーURLの有効性'**
  String get checklistItemPrivacyPolicyUrl;

  /// No description provided for @checklistItemAgeRating.
  ///
  /// In ja, this message translates to:
  /// **'年齢設定'**
  String get checklistItemAgeRating;

  /// No description provided for @checklistItemScreenshotSize.
  ///
  /// In ja, this message translates to:
  /// **'スクリーンショット規定サイズ'**
  String get checklistItemScreenshotSize;

  /// No description provided for @checklistItemMetadataRequiredFields.
  ///
  /// In ja, this message translates to:
  /// **'メタデータ必須項目'**
  String get checklistItemMetadataRequiredFields;

  /// No description provided for @checklistItemContactInfo.
  ///
  /// In ja, this message translates to:
  /// **'連絡先情報'**
  String get checklistItemContactInfo;

  /// No description provided for @checklistItemDemoAccount.
  ///
  /// In ja, this message translates to:
  /// **'審査用デモアカウント'**
  String get checklistItemDemoAccount;

  /// No description provided for @checklistItemExportComplianceInfo.
  ///
  /// In ja, this message translates to:
  /// **'暗号化・輸出コンプライアンス情報'**
  String get checklistItemExportComplianceInfo;

  /// No description provided for @exportTitle.
  ///
  /// In ja, this message translates to:
  /// **'エクスポート・{appName}'**
  String exportTitle(String appName);

  /// No description provided for @exportDescription.
  ///
  /// In ja, this message translates to:
  /// **'審査履歴・リジェクト理由・ビルド失敗ログを1つのファイルにまとめます。'**
  String get exportDescription;

  /// No description provided for @exportGenerate.
  ///
  /// In ja, this message translates to:
  /// **'エクスポートを生成'**
  String get exportGenerate;

  /// No description provided for @exportFailedWithReason.
  ///
  /// In ja, this message translates to:
  /// **'エクスポートに失敗しました: {error}'**
  String exportFailedWithReason(String error);

  /// No description provided for @exportFailed.
  ///
  /// In ja, this message translates to:
  /// **'エクスポートに失敗しました'**
  String get exportFailed;

  /// No description provided for @exportGenerated.
  ///
  /// In ja, this message translates to:
  /// **'{format} を生成しました'**
  String exportGenerated(String format);

  /// No description provided for @exportExpiresAt.
  ///
  /// In ja, this message translates to:
  /// **'有効期限: {date}まで'**
  String exportExpiresAt(String date);

  /// No description provided for @exportShare.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get exportShare;

  /// No description provided for @onboardingPage1Title.
  ///
  /// In ja, this message translates to:
  /// **'複数アプリの状態を、1つの管制塔で'**
  String get onboardingPage1Title;

  /// No description provided for @onboardingPage1Body.
  ///
  /// In ja, this message translates to:
  /// **'App Store Connect と Play Console をまたいで、審査状態・ビルド状態をまとめて見張ります。'**
  String get onboardingPage1Body;

  /// No description provided for @onboardingPage2Title.
  ///
  /// In ja, this message translates to:
  /// **'登録後は完全自動'**
  String get onboardingPage2Title;

  /// No description provided for @onboardingPage2Body.
  ///
  /// In ja, this message translates to:
  /// **'審査通過・リジェクト・ビルド完了を、あなたが確認しに行く前に通知します。'**
  String get onboardingPage2Body;

  /// No description provided for @onboardingPage3Title.
  ///
  /// In ja, this message translates to:
  /// **'APIキーは端末内だけで保管'**
  String get onboardingPage3Title;

  /// No description provided for @onboardingPage3Body.
  ///
  /// In ja, this message translates to:
  /// **'Keychain / EncryptedSharedPreferences に保存し、サーバーには実行時以外保存しません。'**
  String get onboardingPage3Body;

  /// No description provided for @onboardingNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In ja, this message translates to:
  /// **'はじめる'**
  String get onboardingStart;

  /// No description provided for @notificationPromptTitle.
  ///
  /// In ja, this message translates to:
  /// **'審査通過・リジェクトを見逃さないために'**
  String get notificationPromptTitle;

  /// No description provided for @notificationPromptBody.
  ///
  /// In ja, this message translates to:
  /// **'プッシュ通知を許可すると、状態が変わった瞬間にお知らせします。\n（本番実装ではここでOS標準の許可ダイアログを表示します）'**
  String get notificationPromptBody;

  /// No description provided for @notificationPromptAllow.
  ///
  /// In ja, this message translates to:
  /// **'通知を許可する'**
  String get notificationPromptAllow;

  /// No description provided for @notificationPromptLater.
  ///
  /// In ja, this message translates to:
  /// **'あとで'**
  String get notificationPromptLater;

  /// No description provided for @paywallTitle.
  ///
  /// In ja, this message translates to:
  /// **'3本目のアプリを管理するには'**
  String get paywallTitle;

  /// No description provided for @paywallBody.
  ///
  /// In ja, this message translates to:
  /// **'Pro プランでアプリ登録数が無制限になります。\nプッシュ通知即時化・ウィジェット・チーム共有も利用可能です。\n¥600/月 または ¥5,000/年'**
  String get paywallBody;

  /// No description provided for @paywallUpgrade.
  ///
  /// In ja, this message translates to:
  /// **'Pro にアップグレード'**
  String get paywallUpgrade;

  /// No description provided for @paywallLater.
  ///
  /// In ja, this message translates to:
  /// **'あとで'**
  String get paywallLater;

  /// No description provided for @initialScanMessage.
  ///
  /// In ja, this message translates to:
  /// **'登録したアプリの状態を確認しています…'**
  String get initialScanMessage;

  /// No description provided for @initialScanSubMessage.
  ///
  /// In ja, this message translates to:
  /// **'管制塔が起動しています'**
  String get initialScanSubMessage;

  /// No description provided for @initialScanProceedAnyway.
  ///
  /// In ja, this message translates to:
  /// **'ダッシュボードへ進む'**
  String get initialScanProceedAnyway;

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @settingsPlanLabel.
  ///
  /// In ja, this message translates to:
  /// **'プラン'**
  String get settingsPlanLabel;

  /// No description provided for @settingsPlanPro.
  ///
  /// In ja, this message translates to:
  /// **'Pro（無制限）'**
  String get settingsPlanPro;

  /// No description provided for @settingsPlanFree.
  ///
  /// In ja, this message translates to:
  /// **'Free（2アプリまで）'**
  String get settingsPlanFree;

  /// No description provided for @settingsAppsManagementLabel.
  ///
  /// In ja, this message translates to:
  /// **'登録アプリ管理'**
  String get settingsAppsManagementLabel;

  /// No description provided for @settingsAppsCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件登録中'**
  String settingsAppsCount(int count);

  /// No description provided for @settingsNotificationLabel.
  ///
  /// In ja, this message translates to:
  /// **'通知設定'**
  String get settingsNotificationLabel;

  /// No description provided for @settingsNotificationSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'毎朝の状態サマリー通知（未実装・次フェーズ）'**
  String get settingsNotificationSubtitle;

  /// No description provided for @settingsRemoveFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除に失敗しました: {error}'**
  String settingsRemoveFailed(String error);

  /// No description provided for @reviewStatusWaitingReview.
  ///
  /// In ja, this message translates to:
  /// **'審査待ち'**
  String get reviewStatusWaitingReview;

  /// No description provided for @reviewStatusInReview.
  ///
  /// In ja, this message translates to:
  /// **'審査中'**
  String get reviewStatusInReview;

  /// No description provided for @reviewStatusRejected.
  ///
  /// In ja, this message translates to:
  /// **'リジェクト'**
  String get reviewStatusRejected;

  /// No description provided for @reviewStatusApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認済み'**
  String get reviewStatusApproved;

  /// No description provided for @reviewStatusLive.
  ///
  /// In ja, this message translates to:
  /// **'公開中'**
  String get reviewStatusLive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
