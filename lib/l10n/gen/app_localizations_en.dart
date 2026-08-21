// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ririkan';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonAppNotFound => 'App not found';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSelect => 'Select';

  @override
  String get dashboardEmptyMessage => 'No apps registered yet';

  @override
  String get dashboardAddApp => 'Add App';

  @override
  String get dashboardStatusUnknown => 'Status unknown';

  @override
  String get dashboardStatusLoading => 'Loading…';

  @override
  String get dashboardSearchHint => 'Search apps';

  @override
  String get dashboardFilterAll => 'All';

  @override
  String get dashboardSortLabel => 'Sort';

  @override
  String get dashboardSortManual => 'Manual (drag)';

  @override
  String get dashboardSortName => 'Name';

  @override
  String get dashboardSortPlatform => 'Platform';

  @override
  String get dashboardNoMatchMessage => 'No apps match your filters';

  @override
  String dashboardAttentionFilter(int count) {
    return 'Needs Attention ($count)';
  }

  @override
  String get dashboardSelectModeTooltip => 'Select';

  @override
  String dashboardSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get dashboardBulkDeleteTooltip => 'Delete selected apps';

  @override
  String dashboardBulkDeleteConfirmTitle(int count) {
    return 'Delete $count selected apps?';
  }

  @override
  String get dashboardBulkDeleteConfirmMessage =>
      'Deleting will also remove their saved API keys and checklist progress. This cannot be undone.';

  @override
  String get appRegistrationTitle => 'Register App';

  @override
  String get appRegistrationApiKeyRequired => 'Please enter an API key';

  @override
  String get appRegistrationCredentialRequired =>
      'Please fill in Issuer ID, Key ID, and Private Key';

  @override
  String get appRegistrationPackageNamesRequired =>
      'Please enter at least one package name';

  @override
  String get appRegistrationNoAppsFound => 'No linked apps were found';

  @override
  String appRegistrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get appRegistrationBulkFetchDescriptionIos =>
      'Enter your Issuer ID, Key ID, and Private Key (.p8 contents) and every app under that account is fetched from the App Store Connect API and registered at once (no need to register apps one by one).';

  @override
  String get appRegistrationBulkFetchDescriptionAndroid =>
      'The Google Play Developer API has no way to auto-discover apps, so enter the package names you want to register (one shared service account JSON key covers all of them).';

  @override
  String get appRegistrationIssuerIdLabel => 'Issuer ID';

  @override
  String get appRegistrationKeyIdLabel => 'Key ID';

  @override
  String get appRegistrationPrivateKeyLabel =>
      'Private Key (.p8 file contents)';

  @override
  String get appRegistrationPackageNamesLabel => 'Package Names (one per line)';

  @override
  String get appRegistrationPackageNamesHint =>
      'works.petit.app1\nworks.petit.app2';

  @override
  String get appRegistrationIosStep1 => 'Sign in to App Store Connect';

  @override
  String get appRegistrationIosStep2 =>
      'Users and Access → Integrations → Generate a key';

  @override
  String get appRegistrationIosStep3 =>
      'Issue it with at least \"App Manager\" access';

  @override
  String get appRegistrationIosStep4 =>
      'Copy the issued Issuer ID / Key ID / .p8 contents';

  @override
  String get appRegistrationAndroidStep1 => 'Sign in to Google Play Console';

  @override
  String get appRegistrationAndroidStep2 =>
      'API access → Create a service account';

  @override
  String get appRegistrationAndroidStep3 =>
      'Issue it with a minimal-permission role (e.g. view-only)';

  @override
  String get appRegistrationAndroidStep4 =>
      'Copy the service account JSON key contents';

  @override
  String get appRegistrationApiKeyStepsTitle => 'API Key Setup Steps (Manual)';

  @override
  String get appRegistrationApiKeyLabel =>
      'API Key (stored encrypted on this device only)';

  @override
  String get appRegistrationSubmit => 'Fetch & Register Apps';

  @override
  String get appDetailExportTooltip => 'Export';

  @override
  String get appDetailChecklistTooltip => 'Pre-Submission Checklist';

  @override
  String get appDetailTabReviewHistory => 'Review History';

  @override
  String get appDetailTabCrashTrend => 'Crash Trend';

  @override
  String get appDetailTabRevenue => 'Revenue & Downloads';

  @override
  String get appDetailTabRejection => 'Rejection Reasons';

  @override
  String get appDetailTabBuildFailure => 'Build Failure Logs';

  @override
  String get appDetailReviewHistoryEmpty => 'No review history yet';

  @override
  String get appDetailCrashDataEmpty => 'No crash data yet';

  @override
  String appDetailCrashFreeRate(String rate, int count) {
    return 'Crash-free rate $rate% · $count crashes';
  }

  @override
  String get appDetailRevenueEmpty => 'No revenue data yet';

  @override
  String appDetailRevenueSummaryLabel(int days) {
    return 'Revenue (last $days days)';
  }

  @override
  String get appDetailDownloadsTotalLabel => 'Total Downloads';

  @override
  String appDetailRevenueRow(String currency, String amount, int downloads) {
    return '$currency $amount · $downloads DL';
  }

  @override
  String get appDetailRejectionEmpty => 'No rejection history';

  @override
  String get appDetailRejectionUnknownReason => 'Reason unknown';

  @override
  String get appDetailBuildFailureEmpty => 'No build failure logs';

  @override
  String appDetailBuildNumber(String number) {
    return 'Build $number';
  }

  @override
  String get appDetailTabManagement => 'Management';

  @override
  String get appDetailManagementStatusSectionTitle => 'Review Status';

  @override
  String appDetailManagementAutoStatusValue(String status) {
    return 'Automatically fetched status: $status';
  }

  @override
  String get appDetailManagementManualStatusLabel => 'Manual Status Override';

  @override
  String get appDetailManagementAutoOption => 'Automatic (no override)';

  @override
  String get appDetailManagementManualOverrideHint =>
      'This override will be cleared automatically the next time an automatic fetch succeeds.';

  @override
  String get appDetailManagementDatesLabel => 'Dates';

  @override
  String get appDetailManagementSubmittedAtLabel => 'Submitted for Review';

  @override
  String get appDetailManagementReviewStartedAtLabel => 'Review Started';

  @override
  String get appDetailManagementDateNotSet => 'Not set';

  @override
  String get appDetailManagementClearDate => 'Clear';

  @override
  String get appDetailManagementNoteLabel => 'Notes / History';

  @override
  String get appDetailManagementNoteHint =>
      'Record support inquiries or follow-up notes here';

  @override
  String get appDetailManagementTagsLabel => 'Tags';

  @override
  String get appDetailManagementTagsHint => 'Type a tag and press Enter to add';

  @override
  String dashboardManualStatusSuffix(String status) {
    return '$status (Manual)';
  }

  @override
  String get errorReviewStatusFetchFailed => 'Failed to fetch review status';

  @override
  String get errorRejectionDetailsFetchFailed =>
      'Failed to fetch rejection reasons';

  @override
  String get errorBuildFailureLogsFetchFailed =>
      'Failed to fetch build failure logs';

  @override
  String get errorRevenueFetchFailed => 'Failed to fetch revenue summary';

  @override
  String get errorAppDiscoveryFailed => 'Failed to fetch the app list';

  @override
  String get errorCrashSummariesFetchFailed => 'Failed to fetch crash data';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String checklistTitle(String appName) {
    return 'Pre-Submission Checklist · $appName';
  }

  @override
  String checklistProgress(int passCount, int total) {
    return '$passCount / $total items passed';
  }

  @override
  String get checklistResultUnchecked => 'Unchecked';

  @override
  String get checklistResultPass => 'Pass';

  @override
  String get checklistResultWarning => 'Needs Review';

  @override
  String get checklistResultFail => 'Not Addressed';

  @override
  String get checklistItemPrivacyPolicyUrl => 'Privacy Policy URL Validity';

  @override
  String get checklistItemAgeRating => 'Age Rating';

  @override
  String get checklistItemScreenshotSize => 'Screenshot Size Requirements';

  @override
  String get checklistItemMetadataRequiredFields => 'Required Metadata Fields';

  @override
  String get checklistItemContactInfo => 'Contact Information';

  @override
  String get checklistItemDemoAccount => 'Review Demo Account';

  @override
  String get checklistItemExportComplianceInfo =>
      'Encryption Export Compliance Info';

  @override
  String exportTitle(String appName) {
    return 'Export · $appName';
  }

  @override
  String get exportDescription =>
      'Combines review history, rejection reasons, and build failure logs into a single file.';

  @override
  String get exportGenerate => 'Generate Export';

  @override
  String exportFailedWithReason(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportFailed => 'Export failed';

  @override
  String exportGenerated(String format) {
    return '$format generated';
  }

  @override
  String exportExpiresAt(String date) {
    return 'Valid until: $date';
  }

  @override
  String get exportShare => 'Share';

  @override
  String get exportAllTitle => 'Export All Apps';

  @override
  String get exportAllDescription =>
      'Bundles review history, rejection reasons, and build failure logs for every registered app into a single file.';

  @override
  String get dashboardExportAllTooltip => 'Export all apps';

  @override
  String get onboardingPage1Title => 'Monitor every app from one control tower';

  @override
  String get onboardingPage1Body =>
      'Keep watch over review and build status across both App Store Connect and Play Console.';

  @override
  String get onboardingPage2Title => 'Fully automatic after setup';

  @override
  String get onboardingPage2Body =>
      'Get notified of approvals, rejections, and completed builds before you\'d think to check.';

  @override
  String get onboardingPage3Title => 'API keys stay on your device';

  @override
  String get onboardingPage3Body =>
      'Stored in Keychain / EncryptedSharedPreferences — never kept on a server.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get notificationPromptTitle => 'Never miss an approval or rejection';

  @override
  String get notificationPromptBody =>
      'Allow notifications and we\'ll send you a daily reminder to check your apps\' review status.';

  @override
  String get notificationPromptAllow => 'Allow Notifications';

  @override
  String get notificationPromptLater => 'Later';

  @override
  String get paywallTitle => 'Remove ads?';

  @override
  String get paywallBody =>
      'For a small monthly fee, you can remove all ads shown in the app.';

  @override
  String paywallPriceLabel(String price) {
    return 'Remove ads for $price / month';
  }

  @override
  String get paywallUpgrade => 'Remove Ads';

  @override
  String get paywallUnavailable =>
      'This isn\'t available right now. Please try again later.';

  @override
  String get paywallRestore => 'Restore Purchases';

  @override
  String get paywallLater => 'Later';

  @override
  String get dashboardRemoveAds => 'Remove Ads';

  @override
  String get initialScanMessage =>
      'Checking the status of your registered apps…';

  @override
  String get initialScanSubMessage => 'Control tower is starting up';

  @override
  String get initialScanProceedAnyway => 'Proceed to Dashboard';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPlanLabel => 'Plan';

  @override
  String get settingsPlanPro => 'Ad-free';

  @override
  String get settingsPlanFree => 'Ads shown';

  @override
  String get settingsAppsManagementLabel => 'Manage Registered Apps';

  @override
  String settingsAppsCount(int count) {
    return '$count registered';
  }

  @override
  String get settingsNotificationLabel => 'Daily Reminder';

  @override
  String get settingsNotificationSubtitle =>
      'Sends a reminder to check review status every day at 9:00 AM';

  @override
  String get settingsNotificationPermissionDenied =>
      'Notifications are not allowed. Please enable them in your device settings';

  @override
  String settingsRemoveFailed(String error) {
    return 'Failed to remove: $error';
  }

  @override
  String settingsApiKeyMasked(String masked) {
    return 'API Key: $masked';
  }

  @override
  String get settingsRemoveConfirmTitle => 'Remove this app?';

  @override
  String settingsRemoveConfirmMessage(String appName) {
    return 'Removing \"$appName\" will also delete its saved API key and checklist progress. This cannot be undone.';
  }

  @override
  String get settingsRevenueCatLabel => 'RevenueCat Connection';

  @override
  String get settingsRevenueCatConnected => 'Connected';

  @override
  String get settingsRevenueCatNotConnected =>
      'Not connected (revenue/downloads still show sample data)';

  @override
  String get settingsRevenueCatConnectButton => 'Connect';

  @override
  String get settingsRevenueCatDisconnectButton => 'Disconnect';

  @override
  String get settingsRevenueCatConnectHint =>
      'Create an OAuth app in the RevenueCat dashboard and register ririkan://revenuecat-oauth-callback as the redirect URI. Enter the resulting Client ID / Client Secret below, then a browser will open for authorization.';

  @override
  String get settingsRevenueCatClientIdLabel => 'Client ID';

  @override
  String get settingsRevenueCatClientSecretLabel => 'Client Secret';

  @override
  String get settingsRevenueCatConnectSubmit => 'Connect';

  @override
  String settingsRevenueCatConnectFailed(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String settingsRevenueCatDisconnectFailed(String error) {
    return 'Failed to disconnect: $error';
  }

  @override
  String notificationStatusChangedBody(String appName, String status) {
    return '$appName\'s review status changed to \"$status\"';
  }

  @override
  String get reviewStatusWaitingReview => 'Waiting for Review';

  @override
  String get reviewStatusInReview => 'In Review';

  @override
  String get reviewStatusRejected => 'Rejected';

  @override
  String get reviewStatusApproved => 'Approved';

  @override
  String get reviewStatusLive => 'Live';
}
