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
  String get dashboardEmptyMessage => 'No apps registered yet';

  @override
  String get dashboardAddApp => 'Add App';

  @override
  String get dashboardStatusUnknown => 'Status unknown';

  @override
  String get dashboardStatusLoading => 'Loading…';

  @override
  String get appRegistrationTitle => 'Register App';

  @override
  String get appRegistrationFillAllFields => 'Please fill in all fields';

  @override
  String appRegistrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get appRegistrationProgressAlmostDone =>
      'One more step and automatic monitoring begins';

  @override
  String get appRegistrationProgressStart =>
      'Just get through this part — everything after is automatic';

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
  String get appRegistrationDisplayNameLabel => 'App Display Name';

  @override
  String get appRegistrationBundleIdLabel => 'Bundle ID';

  @override
  String get appRegistrationPackageNameLabel => 'Package Name';

  @override
  String get appRegistrationApiKeyLabel =>
      'API Key (stored encrypted on this device only)';

  @override
  String get appRegistrationSubmit => 'Register and Start Initial Scan';

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
      'Allow push notifications and we\'ll tell you the moment something changes.\n(The production build will show the OS permission dialog here.)';

  @override
  String get notificationPromptAllow => 'Allow Notifications';

  @override
  String get notificationPromptLater => 'Later';

  @override
  String get paywallTitle => 'To manage a 3rd app';

  @override
  String get paywallBody =>
      'The Pro plan removes the app limit.\nInstant push notifications, widgets, and team sharing are also included.\n¥600/month or ¥5,000/year';

  @override
  String get paywallUpgrade => 'Upgrade to Pro';

  @override
  String get paywallLater => 'Later';

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
  String get settingsPlanPro => 'Pro (Unlimited)';

  @override
  String get settingsPlanFree => 'Free (up to 2 apps)';

  @override
  String get settingsAppsManagementLabel => 'Manage Registered Apps';

  @override
  String settingsAppsCount(int count) {
    return '$count registered';
  }

  @override
  String get settingsNotificationLabel => 'Notifications';

  @override
  String get settingsNotificationSubtitle =>
      'Daily morning summary notification (not yet implemented)';

  @override
  String settingsRemoveFailed(String error) {
    return 'Failed to remove: $error';
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
